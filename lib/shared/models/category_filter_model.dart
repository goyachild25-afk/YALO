// Modelo de preguntas filtro por categoría
// Cuando el usuario toca una categoría, ve estas preguntas para especificar su servicio

class FilterOption {
  final String id;
  final String label;
  final String? emoji;

  const FilterOption({required this.id, required this.label, this.emoji});
}

class FilterQuestion {
  final String id;
  final String question;
  final String? subtitle;
  final List<FilterOption> options;
  final bool multiSelect; // ¿Puede elegir varias respuestas?
  final bool required;

  const FilterQuestion({
    required this.id,
    required this.question,
    this.subtitle,
    required this.options,
    this.multiSelect = false,
    this.required = true,
  });
}

class CategoryFilterConfig {
  final String categoryId;
  final String categoryName;
  final String emoji;
  final String heroSubtitle;
  final List<FilterQuestion> questions;

  const CategoryFilterConfig({
    required this.categoryId,
    required this.categoryName,
    required this.emoji,
    required this.heroSubtitle,
    required this.questions,
  });
}

// ── Configuración de filtros por categoría ────────────────────────────────────

final Map<String, CategoryFilterConfig> categoryFilters = {

  // ── LIMPIEZA ────────────────────────────────────────────────────────────────
  'cleaning': CategoryFilterConfig(
    categoryId: 'cleaning',
    categoryName: 'Limpieza',
    emoji: '🧹',
    heroSubtitle: 'Cuéntanos qué necesitas y encontramos al prestador ideal',
    questions: [
      // 1. Tipo de espacio
      FilterQuestion(
        id: 'space_type',
        question: '¿Qué tipo de espacio necesitas limpiar?',
        options: [
          FilterOption(id: 'home', label: 'Casa o apartamento', emoji: '🏠'),
          FilterOption(id: 'office', label: 'Oficina o local comercial', emoji: '🏢'),
          FilterOption(id: 'post_construction', label: 'Post-construcción o remodelación', emoji: '🏗️'),
          FilterOption(id: 'vacation', label: 'Casa de vacaciones o Airbnb', emoji: '🏖️'),
          FilterOption(id: 'pool_only', label: 'Piscina (limpieza exclusiva)', emoji: '🏊'),
        ],
      ),
      // 2. Nivel de limpieza
      FilterQuestion(
        id: 'cleaning_level',
        question: '¿Qué nivel de limpieza necesitas?',
        subtitle: 'Esto nos ayuda a estimar el tiempo y precio',
        options: [
          FilterOption(id: 'regular', label: 'Mantenimiento regular', emoji: '✅'),
          FilterOption(id: 'deep', label: 'Limpieza profunda (muebles, electrodomésticos, rincones)', emoji: '✨'),
          FilterOption(id: 'disinfection', label: 'Desinfección y sanitización', emoji: '🦠'),
          FilterOption(id: 'move', label: 'Pre o post mudanza', emoji: '📦'),
        ],
      ),
      // 3. Tamaño
      FilterQuestion(
        id: 'size',
        question: '¿Qué tamaño tiene el espacio?',
        options: [
          FilterOption(id: 'small', label: 'Pequeño (1–2 cuartos o estudio)', emoji: '🏡'),
          FilterOption(id: 'medium', label: 'Mediano (3–4 cuartos)', emoji: '🏠'),
          FilterOption(id: 'large', label: 'Grande (5+ cuartos o +100m²)', emoji: '🏛️'),
        ],
      ),
      // 4. Áreas al detalle (multi-selección libre)
      FilterQuestion(
        id: 'detail_areas',
        question: '¿Qué áreas o detalles quieres incluir?',
        subtitle: 'Selecciona todo lo que aplique — el prestador verá exactamente qué necesitas',
        multiSelect: true,
        required: false,
        options: [
          FilterOption(id: 'kitchen_deep', label: 'Cocina a fondo (campana, horno, refri)', emoji: '🍳'),
          FilterOption(id: 'bathrooms', label: 'Baños (azulejos, sanitarios, espejos)', emoji: '🚿'),
          FilterOption(id: 'windows', label: 'Ventanas y vidrios', emoji: '🪟'),
          FilterOption(id: 'carpets', label: 'Alfombras y tapizado de muebles', emoji: '🛋️'),
          FilterOption(id: 'closets', label: 'Closets y armarios por dentro', emoji: '🚪'),
          FilterOption(id: 'balcony', label: 'Balcón o terraza', emoji: '🌿'),
          FilterOption(id: 'garage', label: 'Garaje o cochera', emoji: '🚗'),
          FilterOption(id: 'walls', label: 'Paredes y techos', emoji: '🏠'),
          FilterOption(id: 'appliances', label: 'Electrodomésticos (lavadora, secadora)', emoji: '🫧'),
          FilterOption(id: 'pool_add', label: 'Piscina (como servicio adicional)', emoji: '🏊'),
        ],
      ),
    ],
  ),

  // ── JARDÍN ──────────────────────────────────────────────────────────────────
  'garden': CategoryFilterConfig(
    categoryId: 'garden',
    categoryName: 'Jardín y exteriores',
    emoji: '🌿',
    heroSubtitle: 'Dinos qué necesita tu jardín o exterior',
    questions: [
      FilterQuestion(
        id: 'garden_service',
        question: '¿Qué necesitas para tu jardín?',
        multiSelect: true,
        subtitle: 'Puedes elegir varias opciones',
        options: [
          FilterOption(id: 'mowing', label: 'Corte de césped', emoji: '🌱'),
          FilterOption(id: 'pruning', label: 'Poda de árboles o arbustos', emoji: '✂️'),
          FilterOption(id: 'planting', label: 'Siembra y diseño de jardín', emoji: '🌺'),
          FilterOption(id: 'weeding', label: 'Remoción de maleza', emoji: '🪴'),
          FilterOption(id: 'irrigation', label: 'Sistema de riego', emoji: '💧'),
          FilterOption(id: 'cleaning', label: 'Limpieza general de exteriores', emoji: '🧹'),
        ],
      ),
      FilterQuestion(
        id: 'garden_size',
        question: '¿Qué tamaño tiene el área?',
        options: [
          FilterOption(id: 'small', label: 'Pequeño (jardín de apartamento o patio)', emoji: '🪴'),
          FilterOption(id: 'medium', label: 'Mediano (jardín de casa residencial)', emoji: '🌿'),
          FilterOption(id: 'large', label: 'Grande (finca, condominio o negocio)', emoji: '🌳'),
        ],
      ),
    ],
  ),

  // ── MASCOTAS ────────────────────────────────────────────────────────────────
  'pets': CategoryFilterConfig(
    categoryId: 'pets',
    categoryName: 'Cuidado de mascotas',
    emoji: '🐾',
    heroSubtitle: '¿Qué necesita tu peludo hoy?',
    questions: [
      FilterQuestion(
        id: 'pet_service',
        question: '¿Qué servicio necesitas?',
        options: [
          FilterOption(id: 'bath_grooming', label: 'Baño y grooming', emoji: '🛁'),
          FilterOption(id: 'walk', label: 'Paseo diario', emoji: '🦮'),
          FilterOption(id: 'daycare_home', label: 'Guardería en tu hogar (viene el cuidador)', emoji: '🏠'),
          FilterOption(id: 'daycare_away', label: 'Cuidado en casa del prestador', emoji: '🏡'),
          FilterOption(id: 'vet_accompany', label: 'Acompañamiento veterinario', emoji: '🏥'),
        ],
      ),
      FilterQuestion(
        id: 'pet_type',
        question: '¿Qué tipo de mascota tienes?',
        multiSelect: true,
        options: [
          FilterOption(id: 'small_dog', label: 'Perro pequeño (menos de 10 kg)', emoji: '🐩'),
          FilterOption(id: 'medium_dog', label: 'Perro mediano (10–25 kg)', emoji: '🐕'),
          FilterOption(id: 'large_dog', label: 'Perro grande (más de 25 kg)', emoji: '🦴'),
          FilterOption(id: 'cat', label: 'Gato', emoji: '🐱'),
          FilterOption(id: 'other', label: 'Otra mascota', emoji: '🐾'),
        ],
      ),
      FilterQuestion(
        id: 'pet_count',
        question: '¿Cuántas mascotas?',
        options: [
          FilterOption(id: 'one', label: 'Una mascota', emoji: '1️⃣'),
          FilterOption(id: 'two', label: 'Dos mascotas', emoji: '2️⃣'),
          FilterOption(id: 'three_plus', label: 'Tres o más', emoji: '🐾'),
        ],
      ),
    ],
  ),

  // ── VEHÍCULOS ───────────────────────────────────────────────────────────────
  'vehicles': CategoryFilterConfig(
    categoryId: 'vehicles',
    categoryName: 'Lavado de vehículos',
    emoji: '🚗',
    heroSubtitle: 'Tu vehículo luce como nuevo',
    questions: [
      FilterQuestion(
        id: 'wash_type',
        question: '¿Qué tipo de lavado necesitas?',
        options: [
          FilterOption(id: 'exterior', label: 'Lavado exterior (carrocería)', emoji: '🚿'),
          FilterOption(id: 'interior', label: 'Limpieza interior (aspirado y muebles)', emoji: '🪑'),
          FilterOption(id: 'full', label: 'Lavado completo (exterior + interior)', emoji: '✨'),
          FilterOption(id: 'detailing', label: 'Detailing profesional (encerado, pulido)', emoji: '💎'),
          FilterOption(id: 'engine', label: 'Lavado de motor', emoji: '⚙️'),
        ],
      ),
      FilterQuestion(
        id: 'vehicle_type',
        question: '¿Qué tipo de vehículo?',
        options: [
          FilterOption(id: 'sedan', label: 'Sedán o Hatchback', emoji: '🚗'),
          FilterOption(id: 'suv', label: 'SUV o Jeep', emoji: '🚙'),
          FilterOption(id: 'pickup', label: 'Pickup o Camioneta', emoji: '🛻'),
          FilterOption(id: 'motorcycle', label: 'Motocicleta', emoji: '🏍️'),
          FilterOption(id: 'other', label: 'Otro (van, bus, etc.)', emoji: '🚐'),
        ],
      ),
      FilterQuestion(
        id: 'vehicle_count',
        question: '¿Cuántos vehículos?',
        options: [
          FilterOption(id: 'one', label: 'Un vehículo', emoji: '1️⃣'),
          FilterOption(id: 'two', label: 'Dos vehículos', emoji: '2️⃣'),
          FilterOption(id: 'fleet', label: 'Flota (3 o más)', emoji: '🚘'),
        ],
      ),
    ],
  ),

  // ── MANTENIMIENTO ───────────────────────────────────────────────────────────
  'maintenance': CategoryFilterConfig(
    categoryId: 'maintenance',
    categoryName: 'Mantenimiento del hogar',
    emoji: '🔧',
    heroSubtitle: 'Dinos qué necesita reparación o mejora',
    questions: [
      FilterQuestion(
        id: 'maintenance_type',
        question: '¿Qué tipo de servicio necesitas?',
        multiSelect: true,
        subtitle: 'Puedes elegir varios',
        options: [
          FilterOption(id: 'plumbing', label: 'Plomería (tuberías, fugas, instalaciones)', emoji: '🔧'),
          FilterOption(id: 'electrical', label: 'Electricidad (instalaciones, reparaciones)', emoji: '⚡'),
          FilterOption(id: 'painting', label: 'Pintura (interior, exterior, texturas)', emoji: '🎨'),
          FilterOption(id: 'carpentry', label: 'Carpintería (muebles, closets, puertas)', emoji: '🪚'),
          FilterOption(id: 'ac', label: 'Aire acondicionado (limpieza y mantenimiento)', emoji: '❄️'),
          FilterOption(id: 'pest', label: 'Control de plagas (fumigación)', emoji: '🪲'),
          FilterOption(id: 'general', label: 'Reparaciones generales (handyman)', emoji: '🛠️'),
        ],
      ),
      FilterQuestion(
        id: 'urgency',
        question: '¿Qué tan urgente es?',
        options: [
          FilterOption(id: 'urgent', label: 'Urgente — necesito ayuda hoy o mañana', emoji: '🚨'),
          FilterOption(id: 'soon', label: 'Pronto — esta semana', emoji: '⏰'),
          FilterOption(id: 'normal', label: 'Normal — puedo esperar', emoji: '📅'),
        ],
      ),
      FilterQuestion(
        id: 'property_type',
        question: '¿Dónde se realizará el trabajo?',
        options: [
          FilterOption(id: 'house', label: 'Casa o apartamento', emoji: '🏠'),
          FilterOption(id: 'office', label: 'Oficina o local', emoji: '🏢'),
          FilterOption(id: 'construction', label: 'Obra o construcción', emoji: '🏗️'),
        ],
      ),
    ],
  ),

  // ── CUIDADO DE PERSONAS ─────────────────────────────────────────────────────
  'caregiving': CategoryFilterConfig(
    categoryId: 'caregiving',
    categoryName: 'Cuidado de personas',
    emoji: '❤️',
    heroSubtitle: 'Cuidadores verificados y de confianza',
    questions: [
      FilterQuestion(
        id: 'care_for',
        question: '¿Para quién necesitas el cuidado?',
        options: [
          FilterOption(id: 'elder', label: 'Adulto mayor (60+ años)', emoji: '👴'),
          FilterOption(id: 'child', label: 'Niño o niña', emoji: '👶'),
          FilterOption(id: 'both', label: 'Adulto mayor y niños', emoji: '👨‍👩‍👧'),
          FilterOption(id: 'disability', label: 'Persona con discapacidad', emoji: '♿'),
        ],
      ),
      FilterQuestion(
        id: 'care_hours',
        question: '¿Cuánto tiempo necesitas al día?',
        options: [
          FilterOption(id: 'few_hours', label: 'Pocas horas (1–4 horas)', emoji: '⏱️'),
          FilterOption(id: 'half_day', label: 'Medio día (4–6 horas)', emoji: '🕛'),
          FilterOption(id: 'full_day', label: 'Día completo (6–10 horas)', emoji: '🌅'),
          FilterOption(id: 'overnight', label: 'Con pernocta', emoji: '🌙'),
        ],
      ),
      FilterQuestion(
        id: 'care_days',
        question: '¿Con qué frecuencia?',
        options: [
          FilterOption(id: 'once', label: 'Fecha puntual', emoji: '1️⃣'),
          FilterOption(id: 'weekly', label: 'Varios días a la semana', emoji: '📅'),
          FilterOption(id: 'daily', label: 'Todos los días', emoji: '🔄'),
          FilterOption(id: 'permanent', label: 'Tiempo completo (trabajo fijo)', emoji: '📋'),
        ],
      ),
    ],
  ),

  // ── COCINA ──────────────────────────────────────────────────────────────────
  'cooking': CategoryFilterConfig(
    categoryId: 'cooking',
    categoryName: 'Cocina y catering',
    emoji: '🍳',
    heroSubtitle: 'Comida deliciosa preparada en tu hogar',
    questions: [
      FilterQuestion(
        id: 'cooking_type',
        question: '¿Qué tipo de servicio culinario necesitas?',
        options: [
          FilterOption(id: 'daily_meals', label: 'Comidas del día (almuerzo y/o cena)', emoji: '🍽️'),
          FilterOption(id: 'event', label: 'Evento especial (cumpleaños, reunión, etc.)', emoji: '🎉'),
          FilterOption(id: 'weekly_prep', label: 'Preparación semanal (meal prep)', emoji: '🥡'),
          FilterOption(id: 'special_diet', label: 'Dieta especial (keto, vegano, diabético, etc.)', emoji: '🥗'),
          FilterOption(id: 'baking', label: 'Repostería y panadería', emoji: '🎂'),
        ],
      ),
      FilterQuestion(
        id: 'people_count',
        question: '¿Para cuántas personas?',
        options: [
          FilterOption(id: 'small', label: '1–2 personas', emoji: '👤'),
          FilterOption(id: 'medium', label: '3–5 personas', emoji: '👨‍👩‍👧'),
          FilterOption(id: 'large', label: '6–15 personas', emoji: '👨‍👩‍👧‍👦'),
          FilterOption(id: 'event', label: '+15 personas (evento)', emoji: '🎊'),
        ],
      ),
    ],
  ),

  // ── MUDANZAS ────────────────────────────────────────────────────────────────
  'moving': CategoryFilterConfig(
    categoryId: 'moving',
    categoryName: 'Mudanzas y carga',
    emoji: '📦',
    heroSubtitle: 'Tu mudanza organizada y sin estrés',
    questions: [
      FilterQuestion(
        id: 'moving_type',
        question: '¿Qué tipo de mudanza necesitas?',
        options: [
          FilterOption(id: 'loading', label: 'Solo ayuda con carga y descarga', emoji: '💪'),
          FilterOption(id: 'local', label: 'Mudanza local (mismo cantón o ciudad)', emoji: '📍'),
          FilterOption(id: 'provincial', label: 'Mudanza entre ciudades o provincias', emoji: '🗺️'),
          FilterOption(id: 'storage', label: 'Traslado a bodega o almacenamiento', emoji: '🏪'),
        ],
      ),
      FilterQuestion(
        id: 'volume',
        question: '¿Cuánto necesitas mover?',
        options: [
          FilterOption(id: 'few', label: 'Pocos artículos (mueble, caja, electrodoméstico)', emoji: '📦'),
          FilterOption(id: 'apartment', label: 'Apartamento pequeño (estudio o 1 habitación)', emoji: '🏢'),
          FilterOption(id: 'house', label: 'Casa completa (2–3 habitaciones)', emoji: '🏠'),
          FilterOption(id: 'large', label: 'Casa grande o empresa (4+ habitaciones)', emoji: '🏛️'),
        ],
      ),
      FilterQuestion(
        id: 'packing',
        question: '¿Necesitas servicio de empaque?',
        options: [
          FilterOption(id: 'no_packing', label: 'No, yo empaco todo', emoji: '✅'),
          FilterOption(id: 'partial', label: 'Solo artículos delicados (vajilla, electrónicos)', emoji: '📱'),
          FilterOption(id: 'full_packing', label: 'Sí, empaque completo de todo', emoji: '🗃️'),
        ],
      ),
    ],
  ),
};
