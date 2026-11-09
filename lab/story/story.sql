-- The story's made-up data. `load-story` runs this straight after
-- Twenty's own demo data, and changes its names to the story's:
--
-- - The workspace is the test data of Animal Inc., the company that
--   makes the app. Development environments use made-up data, never
--   customers', so nothing here comes from Tall Order Co., the customer
--   whose save failed.
-- - You sign in as PM, Animal Inc.'s new product manager, with
--   pm@animal.inc as both the email and the password.
-- - Your colleagues are Rhino in customer success, Rabbit in sales,
--   Snail the developer, Kim the product coach and Croc the CEO, plus
--   Twenty's made-up colleagues, who keep their names and move to
--   animal.inc.
--
-- Twenty's demo data comes from inside its server image, so this file
-- renames it rather than replacing it. The deals still have Twenty's
-- demo names.

\set ON_ERROR_STOP on

BEGIN;

SET LOCAL story.schema = :'schema';

-- No full stop after Inc: Twenty's sign-in page adds its own, in
-- "Welcome, Animal Inc."
UPDATE core.workspace
SET "displayName" = 'Animal Inc', logo = NULL
WHERE id = '20202020-1c25-4d02-bf25-6aeccf7ea419';

CREATE TEMP TABLE story_people (
  user_id uuid,
  member_id uuid,
  first_name text,
  last_name text,
  email text
) ON COMMIT DROP;

INSERT INTO story_people VALUES
  ('20202020-9e3b-46d4-a556-88b9ddc2b034', '20202020-0687-4c41-b707-ed1bfca972a7', 'PM', '', 'pm@animal.inc'),
  ('20202020-3957-4908-9c36-2929a23f8357', '20202020-77d5-4cb6-b60a-f4a835a85d61', 'Rabbit', '', 'rabbit@animal.inc'),
  ('20202020-7169-42cf-bc47-1cfef15264b8', '20202020-1553-45c6-a028-5a9064cce07f', 'Snail', '', 'snail@animal.inc'),
  ('20202020-e6b5-4680-8a32-b8209737156b', '20202020-463f-435b-828c-107e007a2711', 'Kim', '', 'kim@animal.inc'),
  ('20202020-1111-4a01-8001-000000000001', '20202020-1111-4a01-8001-000000000003', 'Croc', '', 'croc@animal.inc');

-- Rhino takes the place of the first of Twenty's 1,000 made-up
-- colleagues, the one with the number 1 in their address.
DO $$
BEGIN
  EXECUTE format(
    'INSERT INTO story_people
     SELECT u.id, m.id, %L, %L, %L
     FROM core."user" u
     JOIN %I."workspaceMember" m ON m."userId" = u.id
     WHERE u.email ~ %L
     LIMIT 1',
    'Rhino', '', 'rhino@animal.inc', current_setting('story.schema'),
    '^[a-z]+\.[a-z]+1@apple\.dev$');
END $$;

-- The demo data writes the same people in several ways, so each old
-- name and address maps to its new one. Full addresses come before the
-- bare domain, so they're replaced first.
CREATE TEMP TABLE story_renames (
  position int,
  old_text text,
  new_text text
) ON COMMIT DROP;

INSERT INTO story_renames VALUES
  (1, 'tim@apple.dev', 'pm@animal.inc'),
  (2, 'tim@apple.com', 'pm@animal.inc'),
  (3, 'jony.ive@apple.dev', 'rabbit@animal.inc'),
  (4, 'jony.ive@apple.com', 'rabbit@animal.inc'),
  (5, 'jony@apple.dev', 'rabbit@animal.inc'),
  (6, 'phil.schiler@apple.dev', 'snail@animal.inc'),
  (7, 'phil.schiller@apple.com', 'snail@animal.inc'),
  (8, 'phil@apple.dev', 'snail@animal.inc'),
  (9, 'jane.austen@apple.dev', 'kim@animal.inc'),
  (10, 'scott.forstall@apple.dev', 'croc@animal.inc'),
  (11, '@apple.dev', '@animal.inc'),
  (12, 'Tim Apple', 'PM'),
  (13, 'Jony Ive', 'Rabbit'),
  (14, 'Phil Schiller', 'Snail'),
  (15, 'Phil Schiler', 'Snail'),
  (16, 'Jane Austen', 'Kim'),
  (17, 'Scott Forstall', 'Croc'),
  (18, 'timapple@apple.com', 'pm@animal.inc'),
  (19, 'apple.dev-invite-hash', 'animal.inc-invite-hash');

UPDATE core."user" u
SET "firstName" = p.first_name, "lastName" = p.last_name, email = p.email
FROM story_people p
WHERE u.id = p.user_id;

-- The password is pm@animal.inc.
UPDATE core."user"
SET "passwordHash" = '$2b$10$jcyAdWyIDQOfYVxuufzqTe.o9pEdazXXKmXAbJ4PWvqJhDTDOgcSO'
WHERE id = '20202020-9e3b-46d4-a556-88b9ddc2b034';

-- Twenty's other made-up colleagues are all at apple.dev.
UPDATE core."user"
SET email = replace(email, '@apple.dev', '@animal.inc')
WHERE email LIKE '%@apple.dev';

DO $$
DECLARE
  s text := current_setting('story.schema');
  col record;
  r record;
  renamed text;
BEGIN
  EXECUTE format(
    'UPDATE %I."workspaceMember" m
     SET "nameFirstName" = p.first_name, "nameLastName" = p.last_name, "userEmail" = p.email
     FROM story_people p
     WHERE m.id = p.member_id',
    s);

  -- Every record shows who created it and who changed it last.
  FOR col IN
    SELECT c.table_name, c.column_name, m.column_name AS member_column
    FROM information_schema.columns c
    JOIN information_schema.columns m
      ON m.table_schema = c.table_schema
     AND m.table_name = c.table_name
     AND m.column_name = replace(c.column_name, 'Name', 'WorkspaceMemberId')
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema
     AND t.table_name = c.table_name
     AND t.table_type = 'BASE TABLE'
    WHERE c.table_schema = s AND c.column_name IN ('createdByName', 'updatedByName')
  LOOP
    EXECUTE format(
      'UPDATE %1$I.%2$I t
       SET %3$I = trim(p.first_name || '' '' || p.last_name)
       FROM story_people p
       WHERE t.%4$I = p.member_id',
      s, col.table_name, col.column_name, col.member_column);
  END LOOP;

  -- Names and addresses in the emails, calendar events, connected
  -- accounts and workflows. Twenty keeps the accounts and workflows in
  -- its core tables.
  FOR col IN
    SELECT c.table_schema, c.table_name, c.column_name, c.data_type
    FROM information_schema.columns c
    JOIN information_schema.tables t
      ON t.table_schema = c.table_schema
     AND t.table_name = c.table_name
     AND t.table_type = 'BASE TABLE'
    WHERE (c.table_schema = s
           OR (c.table_schema = 'core'
               AND c.table_name IN ('connectedAccount', 'messageChannel',
                                    'calendarChannel', 'workflowVersion',
                                    'workspace')))
      AND c.data_type IN ('text', 'character varying', 'jsonb')
      AND c.is_generated = 'NEVER'
  LOOP
    renamed := format('%I::text', col.column_name);
    FOR r IN SELECT old_text, new_text FROM story_renames ORDER BY position LOOP
      renamed := format('replace(%s, %L, %L)', renamed, r.old_text, r.new_text);
    END LOOP;

    EXECUTE format(
      'UPDATE %1$I.%2$I SET %3$I = (%4$s)::%5$s WHERE %3$I::text ~ %6$L',
      col.table_schema, col.table_name, col.column_name, renamed,
      CASE WHEN col.data_type = 'jsonb' THEN 'jsonb' ELSE 'text' END,
      'apple\.(dev|com)|Tim Apple|Jony Ive|Phil Schill?er|Jane Austen|Scott Forstall');
  END LOOP;
END $$;

COMMIT;
