--
-- Run this command first to see the output:
-- SET SERVEROUTPUT ON SIZE UNLIMITED;
--
DECLARE
    -- The schema containing the synonyms you want to trace
    v_target_schema VARCHAR2(128) := 'YOUR_SCHEMA_NAME';

    -- Record to hold a single object in the dependency chain
    TYPE r_dependency_node IS RECORD (
        owner           VARCHAR2(128),
        name            VARCHAR2(128),
        type            VARCHAR2(128),
        level           PLS_INTEGER
    );

    -- Table type to hold the list of objects to process
    TYPE t_processing_list IS TABLE OF r_dependency_node INDEX BY VARCHAR2(512);

    l_to_process        t_processing_list;
    l_processed_keys    t_processing_list; -- Used to prevent reprocessing
    l_current_node      r_dependency_node;
    l_node_key          VARCHAR2(512);

BEGIN
    -- 1. Anchor: Find all synonyms in the target schema and add them to the processing list.
    -- These are the root objects of our usage hierarchy.
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
    END LOOP;

    -- 2. Recursive Processing: Loop through the list to find where each object is used.
    WHILE l_to_process.COUNT > 0 LOOP
        -- Get the next object from the list to process
        l_node_key := l_to_process.FIRST;
        l_current_node := l_to_process(l_node_key);
        l_to_process.DELETE(l_node_key);

        -- Skip if we have already processed this exact object
        IF l_processed_keys.EXISTS(l_node_key) THEN
            CONTINUE;
        END IF;

        -- Print the current object in the hierarchy
        dbms_output.put_line(
            LPAD(' ', l_current_node.level * 2, ' ') ||
            l_current_node.owner || '.' || l_current_node.name || ' (' || l_current_node.type || ')'
        );

        -- Mark the object as processed to prevent infinite loops in circular dependencies
        l_processed_keys(l_node_key) := l_current_node;

        -- 3. Find Dependant Objects: Find all objects that REFERENCE the current object.
        FOR r_dep IN (
            SELECT owner, name, type
            FROM dba_dependencies
            WHERE referenced_owner = l_current_node.owner
              AND referenced_name  = l_current_node.name
              -- Exclude the object itself if it has a self-referencing dependency
              AND (owner != l_current_node.owner OR name != l_current_node.name)
        )
        LOOP
            DECLARE
                v_next_key VARCHAR2(512) := r_dep.owner || '.' || r_dep.name;
            BEGIN
                 -- Add the newly found dependent object to the processing list for the next iteration
                 l_to_process(v_next_key).owner := r_dep.owner;
                 l_to_process(v_next_key).name  := r_dep.name;
                 l_to_process(v_next_key).type  := r_dep.type;
                 l_to_process(v_next_key).level := l_current_node.level + 1;
            END;
        END LOOP;
    END LOOP;
END;
/
