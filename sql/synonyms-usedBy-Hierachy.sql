--
-- Run this command first to see the output:
-- SET SERVEROUTPUT ON SIZE UNLIMITED;
--
DECLARE
    -- The schema containing the initial synonyms to trace
    v_target_schema VARCHAR2(128) := 'YOUR_SCHEMA_NAME';

    -- Record to hold a single object in the dependency chain
    TYPE r_dependency_node IS RECORD (
        owner           VARCHAR2(128),
        name            VARCHAR2(128),
        type            VARCHAR2(128),
        level           PLS_INTEGER,
        -- A note to clarify why this node was added to the tree
        reason          VARCHAR2(200)
    );

    -- Table type to hold the list of objects to process
    TYPE t_processing_list IS TABLE OF r_dependency_node INDEX BY VARCHAR2(512);

    l_to_process        t_processing_list;
    l_processed_keys    t_processing_list; -- Used to prevent reprocessing
    l_current_node      r_dependency_node;
    l_node_key          VARCHAR2(512);

BEGIN
    -- 1. Anchor: Find all synonyms in the target schema and add them to the processing list.
    FOR r_syn IN (
        SELECT owner, synonym_name
        FROM dba_synonyms
        WHERE owner = v_target_schema
    )
    LOOP
        l_node_key := r_syn.owner || '.' || r_syn.synonym_name;
        l_to_process(l_node_key).owner := r_syn.owner;
        l_to_process(l_node_key).name  := r_syn.synonym_name;
        l_to_process(l_node_key).type  := 'SYNONYM';
        l_to_process(l_node_key).level := 0;
        l_to_process(l_node_key).reason := 'Initial Synonym';
    END LOOP;

    -- 2. Recursive Processing: Loop through the list to find where each object is used.
    WHILE l_to_process.COUNT > 0 LOOP
        l_node_key := l_to_process.FIRST;
        l_current_node := l_to_process(l_node_key);
        l_to_process.DELETE(l_node_key);

        IF l_processed_keys.EXISTS(l_node_key) THEN
            CONTINUE;
        END IF;

        -- Print the current object in the hierarchy
        dbms_output.put_line(
            LPAD(' ', l_current_node.level * 2, ' ') ||
            l_current_node.owner || '.' || l_current_node.name || ' (' || l_current_node.type || ')' ||
            ' -- ' || l_current_node.reason
        );

        -- Mark the object as processed to prevent infinite loops
        l_processed_keys(l_node_key) := l_current_node;

        -- 3. Find the next level of dependents from two different paths.

        -- PATH A: Find all objects that DIRECTLY use the current object.
        FOR r_dep IN (
            SELECT owner, name, type
            FROM dba_dependencies
            WHERE referenced_owner = l_current_node.owner
              AND referenced_name  = l_current_node.name
              AND (owner != l_current_node.owner OR name != l_current_node.name)
        )
        LOOP
            DECLARE
                v_next_key VARCHAR2(512) := r_dep.owner || '.' || r_dep.name;
            BEGIN
                 l_to_process(v_next_key).owner := r_dep.owner;
                 l_to_process(v_next_key).name  := r_dep.name;
                 l_to_process(v_next_key).type  := r_dep.type;
                 l_to_process(v_next_key).level := l_current_node.level + 1;
                 l_to_process(v_next_key).reason := 'Uses ' || l_current_node.name;
            END;
        END LOOP;

        -- PATH B: Find all OTHER SYNONYMS that point to the current object.
        -- This finds indirect usage paths.
        FOR r_rev_syn IN (
            SELECT owner, synonym_name
            FROM dba_synonyms
            WHERE table_owner = l_current_node.owner
              AND table_name  = l_current_node.name
              -- Exclude the object if it's a synonym pointing to itself, or if it's the node we're already on
              AND (owner != l_current_node.owner OR synonym_name != l_current_node.name)
        )
        LOOP
             DECLARE
                v_next_key VARCHAR2(512) := r_rev_syn.owner || '.' || r_rev_syn.synonym_name;
            BEGIN
                 l_to_process(v_next_key).owner := r_rev_syn.owner;
                 l_to_process(v_next_key).name  := r_rev_syn.synonym_name;
                 l_to_process(v_next_key).type  := 'SYNONYM';
                 l_to_process(v_next_key).level := l_current_node.level + 1;
                 l_to_process(v_next_key).reason := 'Is a synonym for ' || l_current_node.name;
            END;
        END LOOP;
    END LOOP;
END;
/
