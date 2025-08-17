-- Fix security issues by recreating functions with proper security settings
-- Use CASCADE to handle dependencies

-- Drop and recreate get_user_role function with proper security
DROP FUNCTION IF EXISTS public.get_user_role(UUID) CASCADE;
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS user_role
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT role FROM public.profiles WHERE id = user_id;
$$;

-- Recreate the RLS policies that depend on this function
CREATE POLICY "Admins can view all profiles"
    ON public.profiles FOR SELECT
    USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can view all tickets"
    ON public.tickets FOR SELECT
    USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Admins can update all tickets"
    ON public.tickets FOR UPDATE
    USING (public.get_user_role(auth.uid()) = 'admin');

-- Update other functions with proper security
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        'user'
    );
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;