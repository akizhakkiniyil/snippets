WITH dependency_tree (
    object_owner,
    object_name,
    object_type,
    referenced_owner,
    referenced_name,
    referenced_type,
    level,
    path
) AS (
    -- Anchor member: Start with all synonyms in the specified schema
    SELECT
        s.owner,
        s.synonym_name,
        'SYNONYM' AS object_type,
        s.table_owner,
        s.table_name,
        (SELECT object_type FROM all_objects WHERE owner = s.table_owner AND object_name = s.table_name AND ROWNUM = 1) AS referenced_type,
        1 AS level,
        s.owner || '.' || s.synonym_name AS path
    FROM
        all_synonyms s
    WHERE
        s.owner = 'YOUR_SCHEMA_NAME'

    UNION ALL

    -- Recursive member: Find objects that depend on the previous level's objects
    SELECT
        d.owner,
        d.name,
        d.type,
        d.referenced_owner,
        d.referenced_name,
        d.referenced_type,
        dt.level + 1,
        dt.path || ' -> ' || d.owner || '.' || d.name AS path
    FROM
        all_dependencies d
    JOIN
        dependency_tree dt ON d.referenced_owner = dt.object_owner
                           AND d.referenced_name = dt.object_name

    UNION ALL

    -- Recursive member for synonyms: If a referenced object is a synonym, resolve it
    SELECT
        s.owner,
        s.synonym_name,
        'SYNONYM' AS object_type,
        s.table_owner,
        s.table_name,
        (SELECT object_type FROM all_objects WHERE owner = s.table_owner AND object_name = s.table_name AND ROWNUM = 1) AS referenced_type,
        dt.level + 1,
        dt.path || ' -> ' || s.owner || '.' || s.synonym_name AS path
    FROM
        all_synonyms s
    JOIN
        dependency_tree dt ON s.owner = dt.referenced_owner
                           AND s.synonym_name = dt.referenced_name
)
CYCLE path SET is_cycle TO 'Y' DEFAULT 'N'
SELECT
    **level**,
    LPAD(' ', (**level** - 1) * 2) || object_owner || '.' || object_name || ' (' || object_type || ')' AS dependency_hierarchy,
    referenced_owner || '.' || referenced_name || ' (' || referenced_type || ')' AS "REFERENCES"
FROM
    dependency_tree
WHERE
    is_cycle = 'N'
ORDER BY
    path;
-------------------------------------------------------------------
---- Description --------------------------------------------------
-------------------------------------------------------------------
How the Script Works

WITH dependency_tree AS (...): This defines a common table expression (CTE) that recursively queries for dependencies.

Anchor Member: The first SELECT statement initializes the hierarchy. It selects all synonyms from the schema you specify ('YOUR_SCHEMA_NAME'). This is the starting point of our dependency trace.

Recursive Member (Object Dependencies): The second SELECT statement joins dba_dependencies with the results already in dependency_tree. It looks for any database object (VIEW, MATERIALIZED VIEW, etc.) that references an object from the previous level of the hierarchy.

Recursive Member (Synonym Dependencies): The third SELECT statement is crucial for handling nested synonyms. If a referenced object is itself a synonym, this part of the query resolves that synonym and adds it to the dependency tree, continuing the chain.

CYCLE path SET is_cycle TO 'Y' DEFAULT 'N': This clause is a safety measure to detect and prevent infinite loops in the case of circular dependencies.

Final SELECT: The outer query formats the output to display a clear hierarchical tree.

LEVEL: Indicates the depth of the dependency.

dependency_hierarchy: Shows the dependent object, indented to represent its position in the tree.

"REFERENCES": Shows the object that is being referenced.

    
Prerequisites

To run this script successfully, your database user must have SELECT privileges on dba_synonyms and dba_dependencies. If you do not have these privileges, you can request them from your database administrator or use the all_ views (all_synonyms, all_dependencies) which will limit the search to objects you have access to.
