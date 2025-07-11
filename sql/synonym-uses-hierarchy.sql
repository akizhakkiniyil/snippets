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
        parent_path     VARCHAR2(4000)
    );

    -- Table type to hold the list of objects to process
    TYPE t_processing_list IS TABLE OF r_dependency_node INDEX BY VARCHAR2(512);

    l_to_process        t_processing_list;
    l_processed         t_processing_list;
    l_current_node      r_dependency_node;
    l_node_key          VARCHAR2(512);
    l_level             PLS_INTEGER;

BEGIN
    -- 1. Anchor: Find all synonyms in the target schema and add them to the processing list.
    FOR r_syn IN (
        SELECT owner, synonym_name, table_owner, table_name
        FROM all_synonyms
        WHERE owner = v_target_schema
    )
    LOOP
        -- Print the root synonym
        dbms_output.put_line(r_syn.owner || '.' || r_syn.synonym_name || ' (SYNONYM)');

        -- Add the object the synonym points to into the processing list to start the chain
        l_node_key := r_syn.table_owner || '.' || r_syn.table_name;
        l_to_process(l_node_key).owner := r_syn.table_owner;
        l_to_process(l_node_key).name  := r_syn.table_name;
        l_to_process(l_node_key).parent_path := r_syn.owner || '.' || r_syn.synonym_name;
    END LOOP;

    -- 2. Recursive Processing: Loop through the list until it's empty.
    l_level := 1;
    WHILE l_to_process.COUNT > 0 LOOP
        -- Get the next object from the list to process
        l_node_key := l_to_process.FIRST;
        l_current_node := l_to_process(l_node_key);
        l_to_process.DELETE(l_node_key);

        -- Protect against cycles: If we've seen this object before in this path, skip.
        IF INSTR(l_current_node.parent_path, l_current_node.owner || '.' || l_current_node.name) > 0 THEN
           CONTINUE;
        END IF;

        -- Mark as processed to avoid re-processing in different branches
        l_processed(l_node_key) := l_current_node;

        -- Look up the object's real type
        BEGIN
            SELECT object_type
            INTO l_current_node.type
            FROM all_objects
            WHERE owner = l_current_node.owner AND object_name = l_current_node.name
            AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                l_current_node.type := 'NON-EXISTENT';
        END;

        -- Print the current object in the hierarchy
        dbms_output.put_line(
            LPAD(' ', l_level * 2, ' ') || '-> ' ||
            l_current_node.owner || '.' || l_current_node.name || ' (' || l_current_node.type || ')'
        );

        -- 3. Find next level of dependencies
        -- A. If the current object is a synonym, find what it points to.
        IF l_current_node.type = 'SYNONYM' THEN
            FOR r_syn_dep IN (
                SELECT table_owner, table_name
                FROM all_synonyms
                WHERE owner = l_current_node.owner AND synonym_name = l_current_node.name
            )
            LOOP
                DECLARE
                    v_next_key VARCHAR2(512) := r_syn_dep.table_owner || '.' || r_syn_dep.table_name;
                BEGIN
                    IF NOT l_processed.EXISTS(v_next_key) THEN
                        l_to_process(v_next_key).owner := r_syn_dep.table_owner;
                        l_to_process(v_next_key).name  := r_syn_dep.table_name;
                        l_to_process(v_next_key).parent_path := l_current_node.parent_path || ' -> ' || l_node_key;
                    END IF;
                END;
            END LOOP;
        END IF;

        -- B. Find any objects that the current object depends on (e.g., a view depending on a table).
        FOR r_dep IN (
            SELECT referenced_owner, referenced_name
            FROM all_dependencies
            WHERE owner = l_current_node.owner AND name = l_current_node.name
        )
        LOOP
            DECLARE
                v_next_key VARCHAR2(512) := r_dep.referenced_owner || '.' || r_dep.referenced_name;
            BEGIN
                 IF NOT l_processed.EXISTS(v_next_key) THEN
                    l_to_process(v_next_key).owner := r_dep.referenced_owner;
                    l_to_process(v_next_key).name  := r_dep.referenced_name;
                    l_to_process(v_next_key).parent_path := l_current_node.parent_path || ' -> ' || l_node_key;
                END IF;
            END;
        END LOOP;
        l_level := l_level + 1; -- Note: level is an approximation in this model
    END LOOP;
END;
/

-------------------------------------------------------------------
---- Description --------------------------------------------------
-------------------------------------------------------------------
This script builds the complete dependency tree for all synonyms in a specified schema. It handles nested dependencies (including other synonyms) and protects against circular paths.

How to Run:

Open a SQL client (like SQL*Plus or SQL Developer).

Enable server output to see the results by running: SET SERVEROUTPUT ON;

Copy and paste the entire block below and execute it.

Change the value of v_target_schema to the schema you want to analyze.
