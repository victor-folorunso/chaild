-- 005_rpc_delete_user.sql
-- Adds a SECURITY DEFINER RPC that lets an authenticated user delete their own
-- auth.users row. The FK cascade from auth.users -> public.profiles handles
-- profile cleanup automatically.

CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only allow a user to delete their own account.
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

-- Revoke from public, grant only to authenticated users.
REVOKE ALL ON FUNCTION public.delete_user() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user() TO authenticated;
