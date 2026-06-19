# 🔒 Ejecutar Migración RLS en Supabase

## Problema

Las solicitudes de clientes **no llegan al dashboard del prestador** porque falta ejecutar las políticas RLS (Row Level Security) que permiten que los prestadores vean y acepten solicitudes pending.

## Solución

Copia este SQL y ejecútalo en **Supabase Dashboard → SQL Editor**:

```sql
-- RLS policies for broadcast bookings dispatch
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'bookings' AND policyname = 'View open requests'
  ) THEN
    CREATE POLICY "View open requests" ON bookings
      FOR SELECT TO authenticated
      USING (provider_id IS NULL AND status = 'pending');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'bookings' AND policyname = 'Accept open requests'
  ) THEN
    CREATE POLICY "Accept open requests" ON bookings
      FOR UPDATE TO authenticated
      USING  (provider_id IS NULL AND status = 'pending')
      WITH CHECK (provider_id IS NOT NULL);
  END IF;
END $$;
```

## Pasos

1. Abre https://supabase.com/dashboard/project/ivexcnunszcqoqzzdlfz/sql/new
2. Pega el SQL arriba
3. Haz clic en **Run** (o presiona Ctrl+Enter)
4. Deberías ver "Success, 0 rows" (las políticas ya existen o se crearon)

## Qué hace esta migración

- ✅ Crea la política "View open requests" → prestadores ven solicitudes pending
- ✅ Crea la política "Accept open requests" → prestadores pueden aceptar (set provider_id)

**Después de ejecutar esto, los prestadores podrán ver y aceptar solicitudes correctamente.**
