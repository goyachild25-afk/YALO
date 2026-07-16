-- Motivo de suspensión visible para el usuario suspendido.
-- Antes is_active=false no llevaba ningún motivo asociado, y de todos
-- modos no bloqueaba nada en el cliente (ver AuthController.signIn y
-- app_router.dart para el enforcement real).
alter table public.profiles add column if not exists suspension_reason text;
