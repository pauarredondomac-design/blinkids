from fpdf import FPDF
from fpdf.enums import XPos, YPos
import datetime

# ── Colores ───────────────────────────────────────────────────────────────────
DARK_BG   = (13,  18,  48)
ACCENT    = (99,  102, 241)
ACCENT2   = (16,  185, 129)
MID_GRAY  = (100, 116, 139)
WHITE     = (255, 255, 255)
LIGHT_BG  = (241, 245, 255)
DARK_TEXT = (15,  23,  42)

ROW_H = 7   # altura fija de fila en todas las tablas

class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=True, margin=18)

    # ── Cabecera ──────────────────────────────────────────────────────────────
    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*DARK_BG)
        self.rect(0, 0, 210, 12, 'F')
        self.set_font('Helvetica', 'B', 8)
        self.set_text_color(*WHITE)
        self.set_y(3)
        self.cell(0, 6, 'FinQuest  |  Documento Tecnico del Proyecto', align='C')
        self.set_text_color(*DARK_TEXT)
        self.ln(10)

    # ── Pie ───────────────────────────────────────────────────────────────────
    def footer(self):
        self.set_y(-12)
        self.set_font('Helvetica', '', 7)
        self.set_text_color(*MID_GRAY)
        self.cell(0, 6, f'Pagina {self.page_no()}  |  Generado {datetime.date.today().strftime("%d/%m/%Y")}', align='C')

    # ── Helpers internos ──────────────────────────────────────────────────────
    def _usable(self):
        return self.w - self.l_margin - self.r_margin

    def _truncate(self, txt, max_w):
        """Trunca texto para que quepa en max_w mm con fuente actual."""
        if self.get_string_width(txt) <= max_w:
            return txt
        while txt and self.get_string_width(txt + '...') > max_w:
            txt = txt[:-1]
        return txt + '...'

    # ── Bloques de texto ──────────────────────────────────────────────────────
    def section_title(self, txt):
        self.ln(4)
        self.set_fill_color(*ACCENT)
        self.set_text_color(*WHITE)
        self.set_font('Helvetica', 'B', 11)
        self.cell(0, 9, f'  {txt}',
                  new_x=XPos.LMARGIN, new_y=YPos.NEXT, fill=True)
        self.set_text_color(*DARK_TEXT)
        self.ln(2)

    def sub_title(self, txt):
        self.ln(3)
        self.set_font('Helvetica', 'B', 10)
        self.set_text_color(*ACCENT)
        self.cell(0, 6, txt, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.set_text_color(*DARK_TEXT)

    def body(self, txt):
        self.set_font('Helvetica', '', 9)
        self.set_text_color(*DARK_TEXT)
        self.multi_cell(0, 5, txt,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        self.ln(1)

    def bullet(self, txt, indent=5):
        self.set_font('Helvetica', '', 9)
        self.set_x(self.l_margin + indent)
        self.cell(5, 5, '-')
        self.multi_cell(self._usable() - indent - 5, 5, txt,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    # ── Tablas ────────────────────────────────────────────────────────────────
    def table_header(self, cols, widths):
        """Dibuja la cabecera de tabla. El ultimo width puede ser 0 = resto."""
        self.set_fill_color(*DARK_BG)
        self.set_text_color(*WHITE)
        self.set_font('Helvetica', 'B', 8)
        usable = self._usable()
        resolved = self._resolve_widths(widths, usable)
        for i, (col, w) in enumerate(zip(cols, resolved)):
            last = (i == len(cols) - 1)
            nx = XPos.LMARGIN if last else XPos.RIGHT
            ny = YPos.NEXT    if last else YPos.TOP
            self.cell(w, ROW_H, col, border=1, fill=True,
                      new_x=nx, new_y=ny)
        self.set_text_color(*DARK_TEXT)

    def _resolve_widths(self, widths, usable):
        """Sustituye el 0 final por el espacio restante."""
        fixed = sum(w for w in widths if w != 0)
        return [w if w != 0 else usable - fixed for w in widths]

    def table_row(self, cells, widths, bold_first=True, shade=False):
        """Fila de tabla de N columnas con altura fija. Trunca si no cabe."""
        fill = LIGHT_BG if shade else WHITE
        self.set_fill_color(*fill)
        usable = self._usable()
        resolved = self._resolve_widths(widths, usable)

        # Verificar espacio para evitar que la fila se parta entre paginas
        if self.get_y() + ROW_H > self.h - self.b_margin:
            self.add_page()

        for i, (cell_txt, w) in enumerate(zip(cells, resolved)):
            last = (i == len(cells) - 1)
            if bold_first and i == 0:
                self.set_font('Helvetica', 'B', 8)
            else:
                self.set_font('Helvetica', '', 8)
            txt = self._truncate(str(cell_txt), w - 2)  # -2 de padding
            nx = XPos.LMARGIN if last else XPos.RIGHT
            ny = YPos.NEXT    if last else YPos.TOP
            self.cell(w, ROW_H, txt, border=1, fill=True,
                      new_x=nx, new_y=ny)

    def code_block(self, txt):
        self.set_font('Courier', '', 8)
        self.set_fill_color(*LIGHT_BG)
        self.multi_cell(0, 5, txt, border=1, fill=True,
                        new_x=XPos.LMARGIN, new_y=YPos.NEXT)


# ═════════════════════════════════════════════════════════════════════════════
pdf = PDF()
pdf.set_margins(15, 15, 15)

# ─── PORTADA ─────────────────────────────────────────────────────────────────
pdf.add_page()
pdf.set_fill_color(*DARK_BG)
pdf.rect(0, 0, 210, 297, 'F')

pdf.set_y(55)
pdf.set_font('Helvetica', 'B', 54)
pdf.set_text_color(*WHITE)
pdf.cell(0, 22, 'FinQuest', align='C',
         new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.set_font('Helvetica', '', 15)
pdf.set_text_color(160, 170, 220)
pdf.cell(0, 9, 'Videojuego educativo de finanzas para ninos 8-13 anos',
         align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.ln(8)
pdf.set_fill_color(*ACCENT)
pdf.rect(55, pdf.get_y(), 100, 1, 'F')
pdf.ln(10)

datos = [
    ('Plataforma',  'Android / iOS  (Flutter)'),
    ('Backend',     'Supabase  (PostgreSQL + Auth + RLS)'),
    ('Mercado',     'Mexico'),
    ('Estado',      'En desarrollo activo'),
    ('Fecha',       datetime.date.today().strftime('%d de %B de %Y')),
]
for k, v in datos:
    pdf.set_font('Helvetica', 'B', 10)
    pdf.set_text_color(160, 170, 220)
    pdf.cell(65, 8, k, align='R')
    pdf.set_font('Helvetica', '', 10)
    pdf.set_text_color(*WHITE)
    pdf.cell(0, 8, v, new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.set_y(265)
pdf.set_font('Helvetica', '', 8)
pdf.set_text_color(100, 110, 160)
pdf.cell(0, 5, 'Documento generado automaticamente  |  Confidencial', align='C')

# ─── 1. VISION GENERAL ───────────────────────────────────────────────────────
pdf.add_page()
pdf.section_title('1. Vision General del Proyecto')
pdf.body(
    'FinQuest es un videojuego educativo de finanzas personales para ninos de 8 a 13 anos. '
    'Ensena conceptos financieros basicos (ahorro, presupuesto, inversion, trabajo) '
    'de forma ludica mediante mundos explorables, misiones, trivia y mini-juegos. '
    'Disenado en modo horizontal exclusivo con estetica de videojuego retro-moderno.'
)
pdf.sub_title('Publico objetivo')
for b in ['Ninos de 8-13 anos (usuarios primarios)',
          'Padres de familia que supervisan y envian monedas virtuales',
          'Mercado principal: Mexico']:
    pdf.bullet(b)
pdf.sub_title('Propuesta de valor')
for b in ['Aprender finanzas jugando, sin contenido teorico aburrido',
          'Control total del padre: aprueba, supervisa y recompensa',
          'Progreso en la nube: no se pierde al cambiar de dispositivo',
          'Vinculacion segura padre-hijo mediante codigos de invitacion de un solo uso']:
    pdf.bullet(b)

# ─── 2. STACK TECNOLOGICO ────────────────────────────────────────────────────
pdf.section_title('2. Stack Tecnologico')
pdf.table_header(['Capa', 'Tecnologia', 'Version / Notas'], [42, 55, 0])
stack = [
    ('UI / App',        'Flutter',             '3.32.1  |  Dart 3'),
    ('Motor 2D',        'Flame',               '^1.18.0'),
    ('Estado global',   'Riverpod',            '^2.5.1'),
    ('Navegacion',      'GoRouter',            '^14.2.0'),
    ('Backend',         'Supabase',            'PostgreSQL 15 + Auth + RLS'),
    ('SDK backend',     'supabase_flutter',    '^2.5.0'),
    ('Auth social',     'google_sign_in',      '^6.2.1  +  OAuth deep link finquest://callback'),
    ('Animaciones',     'flutter_animate',     '^4.5.0'),
    ('Storage local',   'shared_preferences',  '^2.3.2  (session data)'),
    ('Deep links',      'app_links',           '6.4.1  (transitivo de supabase_flutter)'),
    ('Fuente',          'Nunito',              'Google Fonts  |  asset local'),
]
for i, row in enumerate(stack):
    pdf.table_row(row, [42, 55, 0], shade=(i % 2 == 0))
pdf.ln(3)

pdf.sub_title('Principios de arquitectura')
for b in [
    'Feature-first: cada feature tiene carpeta propia con screens y logica',
    'Repositorios como unica fuente de verdad para acceso a datos',
    'Providers de Riverpod como capa de estado entre UI y repositorios',
    'Toda validacion sensible en Supabase (RLS + SECURITY DEFINER)',
    'service_role key NUNCA en la app Flutter (solo anon/public key)',
]:
    pdf.bullet(b)

# ─── 3. ESTRUCTURA DE ARCHIVOS ───────────────────────────────────────────────
pdf.add_page()
pdf.section_title('3. Estructura de Archivos (Flutter)')
pdf.code_block(
    'app/lib/\n'
    '  core/\n'
    '    constants/   app_colors, app_sizes, app_strings, app_theme\n'
    '    router/      app_router.dart, go_router_refresh_stream.dart\n'
    '    theme/       app_theme.dart\n'
    '  data/\n'
    '    models/      profile, wallet, character, question, job,\n'
    '                 mission, item, world, app_notification\n'
    '    repositories/ auth, profile, wallet, character, world,\n'
    '                 question, job, mission, item, notification, parent\n'
    '    services/    supabase_service.dart\n'
    '  features/\n'
    '    auth/        login, splash, register_role, register_profile\n'
    '    tutorial/    tutorial_screen.dart\n'
    '    worlds/\n'
    '      forest/    forest_world_map.dart\n'
    '      space/     space_world_map.dart\n'
    '      misiones/  misiones_screen.dart\n'
    '      preguntas/ preguntas_screen.dart\n'
    '      trabajos/  trabajos_screen.dart + vendedor_frutas/\n'
    '      mercado/   mercado_screen.dart\n'
    '      tienda/    tienda_screen.dart\n'
    '    wallet/      wallet_screen.dart\n'
    '    parent/      parent_home_screen.dart, child_detail_screen.dart\n'
    '  shared/\n'
    '    providers/   auth, profile, wallet, character, world,\n'
    '                 question, job, mission, item, parent\n'
    '    widgets/     profile_bottom_sheet, screen_tutorial,\n'
    '                 fin_button, coin_display, child_notification_bell\n'
    '    helpers/     notification_helper.dart'
)

# ─── 4. PANTALLAS ────────────────────────────────────────────────────────────
pdf.section_title('4. Pantallas Implementadas')
pantallas = [
    ('Auth',        'SplashScreen',          'Determina ruta inicial segun sesion y perfil'),
    ('Auth',        'LoginScreen',           'Login con Google OAuth o email/password'),
    ('Auth',        'RegisterRoleScreen',    'Eleccion de rol: nino o padre'),
    ('Auth',        'RegisterProfileScreen', 'Nombre de usuario y configuracion inicial'),
    ('Onboarding',  'TutorialScreen',        'Tutorial interactivo de bienvenida (1 vez)'),
    ('Mundos',      'WorldSelectorScreen',   'Selector de mundo con tarjetas animadas'),
    ('Mundos',      'ForestWorldMap',        'Mapa del Bosque con 6 edificios interactivos'),
    ('Mundos',      'SpaceWorldMap',         'Mapa del Espacio con 6 edificios interactivos'),
    ('Actividades', 'MisionesScreen',        'Lista de misiones con progreso y recompensas'),
    ('Actividades', 'PreguntasScreen',       'Quiz de trivia financiera con timer y XP'),
    ('Actividades', 'TrabajosScreen',        'Lista de trabajos disponibles'),
    ('Mini-juego',  'VendedorFrutasScreen',  'Mini-juego: calcula el cambio correcto'),
    ('Economia',    'MercadoScreen',         'Mercado P2P entre jugadores'),
    ('Economia',    'TiendaScreen',          'Tienda de cosmeticos con monedas virtuales'),
    ('Economia',    'WalletScreen',          'Cartera con categorias y transacciones'),
    ('Padre',       'ParentHomeScreen',      'Dashboard: hijos vinculados y estadisticas'),
    ('Padre',       'ChildDetailScreen',     'Detalle del hijo: progreso y actividad'),
]
pdf.table_header(['Area', 'Pantalla', 'Descripcion'], [28, 54, 0])
for i, row in enumerate(pantallas):
    pdf.table_row(row, [28, 54, 0], shade=(i % 2 == 0))

# ─── 5. MUNDOS Y EDIFICIOS ───────────────────────────────────────────────────
pdf.add_page()
pdf.section_title('5. Sistema de Mundos y Edificios')
pdf.body(
    'Cada mundo es un mapa 2D horizontal con scroll. El jugador toca edificios '
    'para acceder a cada actividad. El Bosque esta disponible desde el inicio; '
    'el Espacio se desbloquea comprando con monedas virtuales.'
)
pdf.sub_title('Mundos disponibles')
pdf.table_header(['Mundo', 'Costo', 'Estado', 'Estetica'], [50, 25, 35, 0])
mundos = [
    ('El Bosque',  '0',   'Gratis desde inicio',  'Verde / magico'),
    ('El Espacio', '500', 'Desbloqueable',         'Oscuro / cian'),
    ('El Oceano',  '1500','Proximamente',          'Azul / marino'),
    ('El Desierto','3000','Proximamente',           'Naranja / arena'),
]
for i, row in enumerate(mundos):
    pdf.table_row(row, [50, 25, 35, 0], shade=(i % 2 == 0))
pdf.ln(3)

pdf.sub_title('Edificios (identicos en todos los mundos)')
edificios = [
    ('Misiones',  '/world/misiones',  'Misiones de aprendizaje con objetivos'),
    ('Preguntas', '/world/preguntas', 'Quiz de trivia financiera con XP'),
    ('Tienda',    '/world/tienda',    'Compra de cosmeticos y personalizacion'),
    ('Mi Bolsa',  '/wallet',          'Cartera y categorias de ahorro'),
    ('Mercado',   '/world/mercado',   'Mercado peer-to-peer entre jugadores'),
    ('Trabajos',  '/world/trabajos',  'Mini-juegos de trabajo para ganar monedas'),
]
pdf.table_header(['Edificio', 'Ruta', 'Funcion'], [32, 52, 0])
for i, row in enumerate(edificios):
    pdf.table_row(row, [32, 52, 0], shade=(i % 2 == 0))

# ─── 6. PERSONAJE Y PROGRESION ───────────────────────────────────────────────
pdf.section_title('6. Personaje y Progresion (XP)')
pdf.table_header(['Fase', 'Rango XP', 'Descripcion'], [40, 45, 0])
niveles = [
    ('Polluelo',  '0 - 499 XP',    'Inicio del juego'),
    ('Zorro',     '500 - 1999 XP', 'Nivel intermedio'),
    ('Leon',      '2000 - 4999 XP','Nivel avanzado'),
    ('Dragon',    '5000+ XP',      'Nivel legendario'),
]
for i, row in enumerate(niveles):
    pdf.table_row(row, [40, 45, 0], shade=(i % 2 == 0))
pdf.ln(3)
pdf.sub_title('Fuentes de XP')
for b in ['Misiones completadas: 50 XP',
          'Preguntas correctas: 10 XP por respuesta',
          'Trabajos completados: 20-30 XP']:
    pdf.bullet(b)

# ─── 7. SISTEMA ECONOMICO ────────────────────────────────────────────────────
pdf.section_title('7. Sistema Economico (Monedas Virtuales)')
pdf.body(
    'FinQuest usa monedas virtuales (coins) como unica moneda. Los ninos NUNCA '
    'ven ni manejan dinero real. Las transacciones reales son exclusivas del padre '
    'y se validan en el servidor.'
)
pdf.table_header(['Accion', 'Descripcion'], [45, 0])
flujos = [
    ('Ganar monedas',  'Completar trabajos, misiones y preguntas correctas'),
    ('Gastar monedas', 'Comprar items en Tienda o desbloquear mundos'),
    ('Recibir',        'El padre envia monedas virtuales al hijo'),
    ('Mercado P2P',    'Comprar y vender items entre jugadores'),
]
for i, row in enumerate(flujos):
    pdf.table_row(row, [45, 0], shade=(i % 2 == 0))
pdf.ln(3)
pdf.sub_title('Mini-juego: Vendedor de Frutas')
pdf.body(
    'El jugador actua como vendedor y calcula el cambio correcto al cliente. '
    'Refuerza suma, resta y manejo de efectivo. Al completarlo gana monedas y XP.'
)

# ─── 8. SISTEMA PADRE-HIJO ───────────────────────────────────────────────────
pdf.add_page()
pdf.section_title('8. Sistema Padre-Hijo')
pdf.body(
    'Vinculo establecido mediante un codigo de invitacion de 6 caracteres '
    'generado por el padre. Ningun padre puede buscar el perfil de un nino '
    'sin que este ingrese el codigo voluntariamente.'
)
pdf.sub_title('Flujo de vinculacion')
for p in [
    '1. Padre abre su perfil > Agregar hijo > la app genera codigo de 6 chars',
    '2. El padre comparte el codigo con su hijo',
    '3. El hijo abre su perfil > Vincularme con papa/mama > ingresa el codigo',
    '4. RPC redeem_invite_code valida el codigo en Supabase',
    '5. Se crea el vinculo en parent_child automaticamente',
    '6. El perfil del hijo muestra el nombre del padre vinculado en verde',
]:
    pdf.bullet(p, indent=3)
pdf.ln(2)
pdf.sub_title('Capacidades del padre')
for b in ['Ver XP, nivel y monedas de cada hijo vinculado',
          'Enviar monedas virtuales al hijo',
          'Recibir notificaciones de actividad',
          'Generar nuevos codigos (invalida el anterior)',
          'Ver historial de transacciones del hijo']:
    pdf.bullet(b)
pdf.sub_title('Restricciones del nino')
for b in ['Solo monedas virtuales, nunca dinero real',
          'Compras reales exclusivas del padre',
          'No puede buscar perfiles de otros usuarios',
          'Vinculacion solo a traves del codigo del padre']:
    pdf.bullet(b)

# ─── 9. BASE DE DATOS ────────────────────────────────────────────────────────
pdf.section_title('9. Base de Datos (Supabase / PostgreSQL)')
pdf.sub_title('Tablas principales')
tablas = [
    ('profiles',           'Datos del usuario: nombre, rol, tutorials_seen'),
    ('parent_child',       'Vinculo padre-hijo (parent_id, child_id)'),
    ('invite_codes',       'Codigos de invitacion con expiracion y uso unico'),
    ('wallets',            'Cartera de monedas virtuales por usuario'),
    ('wallet_categories',  'Categorias de ahorro dentro de la cartera'),
    ('transactions',       'Historial de movimientos de monedas'),
    ('characters',         'Personaje: XP, nivel, apariencia'),
    ('inventory',          'Items cosmeticos del jugador'),
    ('item_catalog',       'Catalogo de items disponibles en Tienda'),
    ('worlds',             'Mundos disponibles (slug, nombre, costo)'),
    ('world_houses',       'Edificios dentro de cada mundo'),
    ('world_progress',     'Mundos desbloqueados por usuario'),
    ('questions',          'Banco de preguntas de trivia financiera'),
    ('player_answers',     'Respuestas del jugador a preguntas'),
    ('jobs',               'Trabajos disponibles con recompensas'),
    ('job_completions',    'Registro de trabajos completados'),
    ('missions',           'Misiones con objetivos y recompensas'),
    ('mission_participants','Participacion en misiones'),
    ('market_listings',    'Listados activos en el mercado P2P'),
    ('real_purchases',     'Registro de compras reales (solo padres)'),
    ('tutorial_progress',  'Si el usuario completo el tutorial inicial'),
]
pdf.table_header(['Tabla', 'Descripcion'], [58, 0])
for i, row in enumerate(tablas):
    pdf.table_row(row, [58, 0], shade=(i % 2 == 0))
pdf.ln(3)

pdf.sub_title('Funciones RPC (SECURITY DEFINER)')
rpcs = [
    ('generate_invite_code()',      'Genera codigo 6 chars para el padre. Invalida el anterior.'),
    ('redeem_invite_code(p_code)',  'El hijo canjea el codigo. Crea vinculo en parent_child.'),
    ('mark_tutorial_seen(p_key)',   'Marca tutorial como visto en profiles.tutorials_seen.'),
    ('award_xp(p_user, p_xp)',      'Suma XP al personaje del usuario de forma atomica.'),
]
pdf.table_header(['Funcion RPC', 'Descripcion'], [65, 0])
for i, row in enumerate(rpcs):
    pdf.table_row(row, [65, 0], shade=(i % 2 == 0))

# ─── 10. MIGRACIONES SQL ─────────────────────────────────────────────────────
pdf.add_page()
pdf.section_title('10. Migraciones SQL (en orden de ejecucion)')
migraciones = [
    ('001', 'extensions_types',          'Extensiones PostgreSQL y tipos ENUM'),
    ('002', 'core_tables',               'Tablas: profiles, parent_child, wallets, transactions'),
    ('003', 'world_tables',              'Tablas de mundos y world_progress'),
    ('004', 'character_items',           'Personaje, inventario y catalogo de items'),
    ('005', 'question_job_tables',       'Preguntas, trabajos y respuestas del jugador'),
    ('006', 'mission_market_tables',     'Misiones, mercado P2P y compras reales'),
    ('007', 'tutorial_purchases',        'Progreso de tutorial y compras'),
    ('008', 'rls_policies',              'Row Level Security: todas las politicas de acceso'),
    ('009', 'seed_data',                 'Datos iniciales: mundos, preguntas, trabajos, items'),
    ('010', 'parent_notifications',      'Tabla de notificaciones padre-hijo'),
    ('011', 'unique_display_name',       'Restriccion de nombre unico por usuario'),
    ('012', 'tutorials_seen',            'Columna JSONB tutorials_seen en profiles'),
    ('013', 'mark_tutorial_seen',        'Funcion RPC mark_tutorial_seen (SECURITY DEFINER)'),
    ('014', 'invite_codes',              'Tabla invite_codes + RPCs generate y redeem'),
    ('015', 'child_sees_parent_profile', 'Politica RLS: hijo lee perfil del padre vinculado'),
]
pdf.table_header(['#', 'Archivo', 'Contenido'], [14, 64, 0])
for i, row in enumerate(migraciones):
    pdf.table_row(row, [14, 64, 0], shade=(i % 2 == 0))

# ─── 11. SEGURIDAD ───────────────────────────────────────────────────────────
pdf.section_title('11. Seguridad y Privacidad')
pdf.sub_title('Politicas RLS clave')
politicas = [
    ('Perfil propio',    'Solo lee y edita su propio perfil'),
    ('Papa ve hijo',     'Padre lee perfil, cartera y personaje de sus hijos'),
    ('Hijo ve papa',     'Hijo lee display_name del padre vinculado'),
    ('parent_child',     'Solo padre o hijo del vinculo pueden leerlo'),
    ('invite_codes',     'Solo el padre dueno del codigo puede leerlo'),
    ('Mercado',          'Listados activos visibles para todos los autenticados'),
    ('Catalogo',         'Items, mundos, trabajos: lectura publica autenticada'),
    ('Transacciones',    'Solo remitente o destinatario ven la transaccion'),
]
pdf.table_header(['Politica', 'Regla'], [50, 0])
for i, row in enumerate(politicas):
    pdf.table_row(row, [50, 0], shade=(i % 2 == 0))
pdf.ln(3)
pdf.sub_title('Reglas de negocio criticas (no negociables)')
for b in [
    'service_role key NUNCA en la app Flutter',
    'Ninos NUNCA ven dinero real, solo monedas virtuales',
    'Transacciones validadas server-side via Edge Functions o RPC',
    'Compras reales exclusivas del rol padre (validado server-side)',
    'Codigos de invitacion: expiran en 24h, un solo uso',
    'OAuth deep link: finquest://callback registrado en Supabase Dashboard',
]:
    pdf.bullet(b, indent=3)

# ─── 12. TUTORIALES ──────────────────────────────────────────────────────────
pdf.section_title('12. Sistema de Tutoriales')
pdf.body(
    'Cada pantalla puede tener un tutorial que aparece la primera vez. '
    'El estado se guarda en Supabase (profiles.tutorials_seen), no en el '
    'dispositivo, por lo que persiste entre reinstalaciones.'
)
for b in [
    'ScreenTutorial: widget wrapper que muestra la tarjeta si el tutorial no fue visto',
    'profiles.tutorials_seen: columna JSONB con claves de tutoriales vistos',
    'mark_tutorial_seen RPC: merge atomico JSONB (SECURITY DEFINER)',
    'Personaje animado guia al usuario en cada paso',
    'Al cerrar: llama a la RPC -> proximo acceso no muestra el tutorial',
]:
    pdf.bullet(b)

# ─── 13. FLUJOS PRINCIPALES ──────────────────────────────────────────────────
pdf.add_page()
pdf.section_title('13. Flujos Principales de Usuario')
pdf.sub_title('Nuevo nino')
for p in [
    '1. Abre la app -> SplashScreen -> LoginScreen',
    '2. Continuar con Google (OAuth) o email/password',
    '3. Sin perfil -> RegisterRoleScreen -> selecciona "Nino"',
    '4. RegisterProfileScreen -> nombre -> perfil + cartera + personaje en Supabase',
    '5. TutorialScreen (1 sola vez) -> ForestWorldMap',
    '6. Explora edificios, completa actividades, gana XP y monedas',
]:
    pdf.bullet(p, indent=3)
pdf.ln(3)
pdf.sub_title('Nuevo padre')
for p in [
    '1. Mismo proceso de login y registro',
    '2. Selecciona rol "Padre" -> nombre -> perfil en Supabase',
    '3. Tutorial -> ParentHomeScreen (dashboard)',
    '4. Agregar hijo -> se genera codigo de 6 chars automaticamente',
    '5. Hijo ingresa el codigo -> vinculo creado via RPC redeem_invite_code',
    '6. Padre ve estadisticas del hijo en ChildDetailScreen',
]:
    pdf.bullet(p, indent=3)
pdf.ln(3)
pdf.sub_title('Compra de mundo')
for p in [
    '1. Jugador abre perfil -> Cambiar mundo -> WorldSelectorScreen',
    '2. Ve el mundo bloqueado con el precio en monedas',
    '3. Confirma la compra -> WalletRepository.spendCoins() en Supabase',
    '4. WorldRepository.unlockWorld() hace upsert en world_progress',
    '5. Riverpod invalida unlockedWorldsProvider -> UI se actualiza',
    '6. El mundo queda desbloqueado permanentemente en la nube',
]:
    pdf.bullet(p, indent=3)

# ─── 14. ESTADO ACTUAL Y ROADMAP ─────────────────────────────────────────────
pdf.section_title('14. Estado Actual y Roadmap')
pdf.sub_title('Completado')
completado = [
    'Autenticacion Google OAuth y email/password',
    'Sistema de roles: nino y padre con flujos distintos',
    'Registro con nombre de usuario unico',
    'Tutorial de bienvenida por pantalla (estado en Supabase)',
    '2 mundos: Bosque Encantado y Espacio Cosmico',
    '6 edificios por mundo (Misiones, Preguntas, Tienda, Bolsa, Mercado, Trabajos)',
    'Sistema de XP y evolucion del personaje (4 fases)',
    'Cartera de monedas virtuales con categorias de ahorro',
    'Quiz de trivia financiera con timer, feedback y XP',
    'Misiones con seguimiento de progreso',
    'Mini-juego Vendedor de Frutas',
    'Tienda de cosmeticos con inventario',
    'Mercado P2P entre jugadores',
    'Sistema padre-hijo via codigos de invitacion (6 chars, 24h, 1 uso)',
    'Dashboard del padre con estadisticas de hijos',
    'Perfil: nombre del padre vinculado visible para el nino',
    'Compra de mundos persistente en Supabase (world_progress)',
    'Sistema de seguridad RLS completo (15 migraciones)',
    'Deep link OAuth: finquest://callback',
]
for item in completado:
    pdf.bullet(f'[OK]  {item}', indent=3)
pdf.ln(3)
pdf.sub_title('Pendiente / Roadmap')
pendiente = [
    'Push notifications reales (Firebase Cloud Messaging)',
    'Mas mini-juegos de trabajo',
    'Sistema de logros y badges',
    'Ranking / leaderboard entre amigos',
    'Mas mundos (Ciudad, Selva, Mar...)',
    'Modo offline con sincronizacion',
    'Pagos reales (mundos premium)',
    'Soporte iOS (Info.plist para deep links)',
    'Tests automatizados (unit, widget, integration)',
]
for item in pendiente:
    pdf.bullet(f'[ ]   {item}', indent=3)

# ─── CONFIGURACION Y DESPLIEGUE ──────────────────────────────────────────────
pdf.add_page()
pdf.section_title('15. Configuracion y Despliegue')
pdf.sub_title('Variables en app_strings.dart')
for b in ['supabaseUrl: URL del proyecto Supabase',
          'supabaseAnonKey: Clave publica anonima (NUNCA service_role)',
          'oauthRedirectUrl: finquest://callback']:
    pdf.bullet(b)
pdf.sub_title('Configuracion Android')
for b in ['AndroidManifest: orientacion sensorLandscape (solo horizontal)',
          'AndroidManifest: intent-filter scheme=finquest host=callback',
          'launchMode="singleTop" para deep links sin duplicar Activity',
          'windowSoftInputMode="adjustResize" para teclado virtual']:
    pdf.bullet(b)
pdf.sub_title('Supabase Dashboard')
for b in ['Authentication > URL Configuration > Site URL: finquest://callback',
          'Authentication > URL Configuration > Redirect URLs: finquest://callback',
          'Authentication > Providers > Google: habilitado con credenciales OAuth',
          'Ejecutar las 15 migraciones SQL en orden (001 al 015)']:
    pdf.bullet(b)
pdf.sub_title('Comandos de desarrollo')
pdf.code_block(
    '# Instalar dependencias\n'
    'flutter pub get\n\n'
    '# Correr con hot reload\n'
    'flutter run\n\n'
    '# Limpiar cache (cambios estructurales)\n'
    'flutter clean && flutter run\n\n'
    '# Build Android release\n'
    'flutter build apk --release'
)

# ── Guardar ───────────────────────────────────────────────────────────────────
out = r'C:\apps_IOS_android\Juego economia\finquest\FinQuest_Resumen_Tecnico.pdf'
pdf.output(out)
print(f'PDF generado: {out}')
