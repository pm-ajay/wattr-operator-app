/// Tenant → JE → Operator → Pump. A real login auto-scopes to one Tenant
/// and one role; this enum only exists so the UI-only build can preview
/// both views without a real auth flow.
enum UserRole { operator, je }
