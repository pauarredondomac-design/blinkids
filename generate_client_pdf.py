"""Blinkids — Documento de presentacion para cliente. Generado con ReportLab."""
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, PageBreak
)
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT

GOLD         = colors.HexColor('#FFD600')
DARK_BG      = colors.HexColor('#0D1230')
FOREST_GREEN = colors.HexColor('#1B5E20')
TEAL         = colors.HexColor('#006064')
PURPLE       = colors.HexColor('#4A148C')
ORANGE       = colors.HexColor('#E65100')
BLUE         = colors.HexColor('#0D47A1')
GREY_DARK    = colors.HexColor('#263238')
GREY_MED     = colors.HexColor('#546E7A')
GREY_LIGHT   = colors.HexColor('#ECEFF1')
WHITE        = colors.white
BLACK        = colors.HexColor('#1A1A2E')

BASE = getSampleStyleSheet()

def ms(n, **kw):
    return ParagraphStyle(n, parent=BASE['Normal'], **kw)

S_COVER_TITLE = ms('CT',  fontSize=42, leading=48, textColor=WHITE,
    fontName='Helvetica-Bold', alignment=TA_CENTER, spaceAfter=8)
S_COVER_SUB   = ms('CS',  fontSize=16, leading=22, textColor=GOLD,
    fontName='Helvetica-Bold', alignment=TA_CENTER, spaceAfter=6)
S_COVER_TAG   = ms('CTag',fontSize=11, leading=15,
    textColor=colors.HexColor('#B0BEC5'), fontName='Helvetica', alignment=TA_CENTER)
S_SEC_HDR     = ms('SHdr',fontSize=19, leading=24, textColor=WHITE,
    fontName='Helvetica-Bold', alignment=TA_CENTER)
S_SUB         = ms('Sub', fontSize=13, leading=17, textColor=TEAL,
    fontName='Helvetica-Bold', spaceBefore=10, spaceAfter=4)
S_BODY        = ms('Bd',  fontSize=10, leading=14, textColor=BLACK,
    fontName='Helvetica', spaceAfter=4, alignment=TA_JUSTIFY)
S_BULLET      = ms('Bul', fontSize=10, leading=14, textColor=BLACK,
    fontName='Helvetica', leftIndent=12, spaceAfter=2)
S_MAP         = ms('Map', fontSize=9,  leading=13, textColor=BLACK,
    fontName='Courier', spaceAfter=1)
S_FT          = ms('Ft',  fontSize=8,  leading=11, textColor=GREY_MED,
    fontName='Helvetica', alignment=TA_CENTER)

# Estilos para celdas de tabla
S_TH = ms('TH', fontSize=9, leading=13, textColor=WHITE,
    fontName='Helvetica-Bold', spaceAfter=0, spaceBefore=0)
S_TB = ms('TB', fontSize=9, leading=13, textColor=BLACK,
    fontName='Helvetica', spaceAfter=0, spaceBefore=0, alignment=TA_LEFT)
S_TB_BOLD = ms('TBB', fontSize=9, leading=13, textColor=BLACK,
    fontName='Helvetica-Bold', spaceAfter=0, spaceBefore=0)

PW = letter[0] - 2*inch   # ancho utilizable

def p(text, style=None):
    """Paragraph con estilo dado."""
    return Paragraph(text, style or S_BODY)

def bul(text):
    return Paragraph(f'<bullet>•</bullet> {text}', S_BULLET)

def sh(title, color):
    """Encabezado de sección con fondo de color."""
    t = Table([[Paragraph(title, S_SEC_HDR)]], colWidths=[PW],
        style=TableStyle([
            ('BACKGROUND', (0,0),(-1,-1), color),
            ('TOPPADDING',    (0,0),(-1,-1), 12),
            ('BOTTOMPADDING', (0,0),(-1,-1), 12),
            ('LEFTPADDING',   (0,0),(-1,-1), 16),
            ('RIGHTPADDING',  (0,0),(-1,-1), 16),
        ]))
    return [Spacer(1, 10), t, Spacer(1, 6)]

def _base_ts(hbg=None):
    ts = [
        ('FONTNAME',      (0,0),(-1,-1), 'Helvetica'),
        ('FONTSIZE',      (0,0),(-1,-1), 9),
        ('LEADING',       (0,0),(-1,-1), 13),
        ('TOPPADDING',    (0,0),(-1,-1), 5),
        ('BOTTOMPADDING', (0,0),(-1,-1), 5),
        ('LEFTPADDING',   (0,0),(-1,-1), 7),
        ('RIGHTPADDING',  (0,0),(-1,-1), 7),
        ('ROWBACKGROUNDS',(0,0),(-1,-1), [GREY_LIGHT, WHITE]),
        ('GRID',          (0,0),(-1,-1), 0.5, colors.HexColor('#B0BEC5')),
        ('VALIGN',        (0,0),(-1,-1), 'TOP'),
    ]
    if hbg:
        ts += [
            ('BACKGROUND', (0,0),(-1,0), hbg),
            ('ROWBACKGROUNDS',(0,0),(-1,0), [hbg]),
        ]
    return ts

def _prow(row, is_header=False):
    """Convierte fila de strings en fila de Paragraphs."""
    if is_header:
        return [Paragraph(str(c), S_TH) for c in row]
    result = []
    for i, c in enumerate(row):
        style = S_TB_BOLD if i == 0 else S_TB
        result.append(Paragraph(str(c), style))
    return result

def _prows(rows, hbg=None):
    """Convierte lista de filas; primera fila es header si hbg."""
    out = []
    for i, row in enumerate(rows):
        out.append(_prow(row, is_header=(i == 0 and hbg is not None)))
    return out

def t2(rows, w1=None, hbg=None):
    c1 = w1 or PW * 0.33
    return Table(_prows(rows, hbg), colWidths=[c1, PW-c1],
                 style=TableStyle(_base_ts(hbg)))

def t3(rows, hbg=None):
    cw = PW / 3
    return Table(_prows(rows, hbg), colWidths=[cw, cw, cw],
                 style=TableStyle(_base_ts(hbg)))

def t4(rows, ws, hbg=None):
    return Table(_prows(rows, hbg), colWidths=ws,
                 style=TableStyle(_base_ts(hbg)))

# ─── DOCUMENTO ───────────────────────────────────────────────────────────────
OUTPUT = r'C:\apps_IOS_android\Juego economia\finquest\Blinkids_Presentacion_Cliente.pdf'
doc = SimpleDocTemplate(OUTPUT, pagesize=letter,
    leftMargin=inch, rightMargin=inch,
    topMargin=0.75*inch, bottomMargin=0.75*inch,
    title='Blinkids - Presentacion para Cliente')
story = []

# ════════════════════════════════════════════════════════════
# PORTADA
# ════════════════════════════════════════════════════════════
ci = [
    Spacer(1, 30),
    Paragraph('Blinkids', S_COVER_TITLE),
    Spacer(1, 8),
    Paragraph('La aventura de aprender a manejar el dinero', S_COVER_SUB),
    Spacer(1, 18),
    HRFlowable(width='65%', color=GOLD, thickness=2, hAlign='CENTER', spaceAfter=18),
    Paragraph('Documento de Producto  |  Funcionalidades y Flujos de Usuario', S_COVER_TAG),
    Spacer(1, 5),
    Paragraph('Para ninos y jovenes de 8 a 13 anos  |  Mercado Mexico', S_COVER_TAG),
    Spacer(1, 5),
    Paragraph('iOS y Android  |  Junio 2026', S_COVER_TAG),
]
story.append(Table([[c] for c in ci], colWidths=[PW], style=TableStyle([
    ('BACKGROUND',    (0,0),(-1,-1), DARK_BG),
    ('TOPPADDING',    (0,0),(-1,-1), 0),
    ('BOTTOMPADDING', (0,0),(-1,-1), 0),
    ('LEFTPADDING',   (0,0),(-1,-1), 0),
    ('RIGHTPADDING',  (0,0),(-1,-1), 0),
])))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# ÍNDICE
# ════════════════════════════════════════════════════════════
story += sh('Contenido del Documento', GREY_DARK)
story.append(t4([
    ['Sec.', 'Tema', 'Descripcion'],
    ['1',  'Que es Blinkids?',        'Vision, propuesta de valor y tecnologia'],
    ['2',  'Jugador y Personaje',     'Perfil, niveles y XP'],
    ['3',  'Como se juega',           'Flujo general y ciclo de juego'],
    ['4',  'Los Mundos',              'Bosque Magico y Galaxia Espacial'],
    ['5',  'Las Monedas Blink',       'Sistema economico interno'],
    ['6',  'Mi Bolsa',                'Billetera educativa del nino'],
    ['7',  'Preguntas',               'Quiz de educacion financiera'],
    ['8',  'Trabajos',                'Mini-economia de materiales'],
    ['9',  'Misiones',                'Retos con objetivos'],
    ['10', 'Tienda',                  'Compra de materiales e items'],
    ['11', 'Mercado',                 'Comercio entre jugadores'],
    ['12', 'Combustible y Rachas',    'Engagement diario'],
    ['13', 'Salario Semanal',         'Mesada digital del padre'],
    ['14', 'Panel del Padre',         'Control parental y supervision'],
    ['15', 'Tutorial',                'Onboarding del nuevo jugador'],
    ['16', 'Cosmeticos y Medallas',   'Personalizacion y logros'],
    ['17', 'Seguridad',               'Diseno seguro para menores'],
], [PW*0.07, PW*0.33, PW*0.60], hbg=TEAL))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 1. QUE ES BLINKIDS
# ════════════════════════════════════════════════════════════
story += sh('1. Que es Blinkids?', FOREST_GREEN)
story.append(p(
    'Blinkids es un videojuego educativo para moviles (iOS y Android) disenado para '
    'ninos y adolescentes de 8 a 13 anos. Su objetivo es ensennar conceptos de educacion '
    'financiera — ahorro, presupuesto, inversion, comercio y trabajo — de forma natural, '
    'a traves de la mecanica de un juego de rol y aventura.'))
story.append(p(
    'En lugar de clases teoricas, el jugador vive la economia: gana monedas respondiendo '
    'preguntas, las distribuye en categorias de ahorro, las usa para comprar materiales, '
    'los transforma en recompensas con trabajos, y las intercambia con otros jugadores '
    'en el mercado.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Propuesta de valor', S_SUB))
story.append(t2([
    ['Para...', 'Blinkids ofrece...'],
    ['El nino (8-13)',
     'Una aventura con personajes, mundos y misiones donde las decisiones financieras son parte natural del juego.'],
    ['Los padres',
     'Un panel de control donde asignan salario semanal, envian monedas y revisan la actividad del hijo sin intervenir en el juego.'],
    ['La educacion',
     'Contenido de literacia financiera integrado: preguntas con explicaciones, mecanicas de ahorro obligatorio y decision de gasto.'],
], hbg=FOREST_GREEN))
story.append(Spacer(1, 8))
story.append(Paragraph('Tecnologia', S_SUB))
story.append(t2([
    ['Plataforma',    'iOS y Android — codigo unico en Flutter'],
    ['Backend',       'Supabase (PostgreSQL + Autenticacion + Edge Functions)'],
    ['Idioma',        'Espanol (Mexico)'],
    ['Orientacion',   'Solo horizontal (landscape), optimizado para tablets y moviles'],
    ['Edad objetivo', '8 a 13 anos'],
]))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 2. JUGADOR Y PERSONAJE
# ════════════════════════════════════════════════════════════
story += sh('2. El Jugador y su Personaje', PURPLE)
story.append(p(
    'Al registrarse, el jugador crea un perfil con nombre de usuario y elige si es '
    'nino o padre. Los ninos acceden al juego; los padres al panel de control.'))
story.append(Paragraph('El personaje: Blink', S_SUB))
story.append(p(
    'Blink es el personaje guia del jugador durante toda la aventura. Aparece en el '
    'tutorial inicial, en las pantallas de preguntas (reaccionando segun la respuesta), '
    'y en el onboarding de cada nueva pantalla. A medida que el jugador gana '
    'experiencia (XP), Blink sube de nivel.'))
story.append(Paragraph('Sistema de niveles y XP', S_SUB))
story.append(p(
    'Cada accion en el juego otorga puntos de experiencia (XP). Al acumular 100 XP, '
    'el jugador sube de nivel. El nivel se muestra en el HUD del mapa.'))
story.append(t2([
    ['Accion',                              'XP aproximado'],
    ['Responder pregunta correctamente',    '+10 XP por respuesta'],
    ['Completar un trabajo',               '+15 XP por trabajo'],
    ['Participar en una mision',           '+20 XP por mision'],
    ['Completar el tutorial',              'Bonus inicial'],
], hbg=PURPLE))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 3. COMO SE JUEGA
# ════════════════════════════════════════════════════════════
story += sh('3. Como se Juega — Flujo General', BLUE)
story.append(p(
    'El juego sigue un ciclo de actividad diaria. Cada sesion puede durar entre '
    '5 y 30 minutos segun el interes del jugador.'))
story.append(Paragraph('Primera vez (onboarding)', S_SUB))
story.append(t2([
    ['Paso', 'Descripcion'],
    ['1. Registro',
     'El nino crea su cuenta con nombre, correo y contrasena. Elige rol "Nino".'],
    ['2. Tutorial',
     'Blink le da la bienvenida en 4 pantallas animadas: introduce el mapa, la bolsa, los objetivos, y regala 200 monedas de inicio.'],
    ['3. Primer mapa',
     'Llega al Bosque Magico. Ve 6 edificios interactivos y el HUD con sus monedas.'],
    ['4. Explorar',
     'Puede entrar a cualquiera de los 6 modulos libremente.'],
    ['5. Salario',
     'El padre puede vincular al hijo y asignar un salario semanal desde su panel.'],
], w1=PW*0.28, hbg=BLUE))
story.append(Spacer(1, 8))
story.append(Paragraph('Ciclo de juego tipico (sesion recurrente)', S_SUB))
story.append(t2([
    ['Momento',        'Accion'],
    ['Al entrar',      'Se registra actividad diaria (+combustible y racha).'],
    ['Si hay salario', 'Aparece chip "Cobrar" en el HUD.'],
    ['Actividad 1',    'Responde 3-5 preguntas de finanzas (gana monedas y XP).'],
    ['Actividad 2',    'Revisa misiones activas y avanza en sus objetivos.'],
    ['Actividad 3',    'Compra materiales en la Tienda, luego los usa en Trabajos.'],
    ['Actividad 4',    'Visita Mi Bolsa para distribuir sus monedas.'],
    ['Cierre',         'Revisa el progreso de combustible y XP en el HUD.'],
], w1=PW*0.28, hbg=BLUE))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 4. LOS MUNDOS
# ════════════════════════════════════════════════════════════
story += sh('4. Los Mundos (Biomas)', FOREST_GREEN)
story.append(p(
    'Blinkids organiza su contenido en mundos o biomas, cada uno con estetica visual '
    'diferente pero con los mismos 6 modulos de actividad. Esto permite que el juego '
    'se sienta fresco a medida que el jugador avanza.'))
story.append(t3([
    ['Mundo',           'Estetica',                                                          'Estado'],
    ['Bosque Magico',   'Naturaleza verde, casitas de madera, tonos calidos.',               'Activo — mundo inicial'],
    ['Galaxia Espacial','Estacion espacial, fondo estrellado, tonos azul, cian y naranja.',  'Activo — segundo mundo'],
    ['Futuros mundos',  'Oceano, desierto, ciudad futurista, etc.',                          'En roadmap'],
], hbg=FOREST_GREEN))
story.append(Spacer(1, 8))
story.append(Paragraph('Los 6 edificios (presentes en todos los mundos)', S_SUB))
story.append(t3([
    ['Edificio',   'Actividad',                      'Recompensa principal'],
    ['Misiones',   'Retos con objetivos multiples',  'Monedas + XP + Items'],
    ['Preguntas',  'Quiz de finanzas',               'Monedas + XP'],
    ['Tienda',     'Compra materiales y cosmeticos', 'Items / Cosmeticos'],
    ['Mi Bolsa',   'Billetera de ahorro',            'Combustible'],
    ['Mercado',    'Comercio entre jugadores',       'Monedas / Items'],
    ['Trabajos',   'Combinar materiales y ganar',    'Monedas + XP + Items'],
], hbg=FOREST_GREEN))
story.append(Spacer(1, 8))
story.append(Paragraph('El Hangar de Despegue (mundo espacial)', S_SUB))
story.append(p(
    'Cuando el jugador llena al 100% la barra de combustible en el mundo espacial, '
    'aparece el boton especial del Hangar de Despegue. Al entrar:'))
story.append(bul('Animacion de celebracion: "Blink llego a Marte!"'))
story.append(bul('+50 monedas Blink de recompensa.'))
story.append(bul('Se desbloquea el "Traje Dorado" (cosmético exclusivo).'))
story.append(bul('El combustible se reinicia para comenzar un nuevo ciclo.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 5. MONEDAS BLINK
# ════════════════════════════════════════════════════════════
story += sh('5. Las Monedas Blink', ORANGE)
story.append(p(
    'Las monedas Blink son la moneda virtual interna de Blinkids. Representan el poder '
    'economico del jugador dentro del juego. Son completamente ficticias y no tienen '
    'valor monetario real.'))
story.append(Paragraph('Como se obtienen', S_SUB))
story.append(t3([
    ['Fuente',                       'Cantidad aprox.',    'Frecuencia'],
    ['Tutorial de bienvenida',       '+200 monedas',       'Una sola vez'],
    ['Respuesta correcta (quiz)',     '+5 a +15 monedas',  'Por pregunta'],
    ['Completar un trabajo',         '+20 a +60 monedas',  'Por trabajo'],
    ['Salario semanal del padre',    '+20 a +35 monedas',  'Una vez / semana'],
    ['Envio del padre',              'Monto libre',        'Cuando el padre lo decide'],
    ['Misiones completadas',         'Varia por mision',   'Al completar objetivo'],
    ['Hangar de Despegue',           '+50 monedas',        'Al llenar combustible espacial'],
], hbg=ORANGE))
story.append(Spacer(1, 8))
story.append(Paragraph('Como se gastan', S_SUB))
story.append(t2([
    ['Destino', 'Descripcion'],
    ['Tienda',   'Comprar materiales para los Trabajos o cosmeticos para el personaje.'],
    ['Mi Bolsa', 'Distribuir en categorias: Guardar, Banco Estelar, Gastar.'],
    ['Mercado',  'Comprar items publicados por otros jugadores.'],
], hbg=ORANGE))
story.append(Spacer(1, 8))
story.append(Paragraph('Concepto educativo', S_SUB))
story.append(p(
    'Las monedas no son infinitas. El jugador debe decidir como distribuirlas: gastar '
    'en la Tienda o reservar en el Banco Estelar. Esto introduce el concepto de costo '
    'de oportunidad de forma implicita y natural.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 6. MI BOLSA
# ════════════════════════════════════════════════════════════
story += sh('6. Mi Bolsa — La Billetera Educativa', TEAL)
story.append(p(
    'Mi Bolsa es el modulo central de educacion financiera. Es la billetera personal '
    'del nino, organizada en 3 categorias que reflejan habitos financieros reales.'))
story.append(Paragraph('Las 3 categorias', S_SUB))
story.append(t3([
    ['Categoria',     'Icono',             'Concepto ensenado'],
    ['Guardar',       'Cerdo alcancia',    'Ahorro a corto plazo — dinero seguro para pequenas metas personales.'],
    ['Banco Estelar', 'Banco / estrella',  'Ahorro a largo plazo — simula una cuenta bancaria con metas mayores.'],
    ['Gastar',        'Carrito compras',   'Presupuesto de consumo — dinero disponible para uso inmediato.'],
], hbg=TEAL))
story.append(Spacer(1, 8))
story.append(Paragraph('Como funciona', S_SUB))
story.append(bul('El nino ve las 3 categorias con su saldo actual en la pantalla principal.'))
story.append(bul('Puede tocar cualquier categoria para abrir un control deslizante (slider).'))
story.append(bul('El slider permite mover monedas HACIA la categoria (depositar) o DESDE la categoria (retirar al saldo general).'))
story.append(bul('Depositar en Guardar o Banco Estelar otorga +5 puntos de combustible (refuerzo positivo del habito de ahorro).'))
story.append(bul('Depositar en Gastar otorga +3 puntos de combustible.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Logica educativa', S_SUB))
story.append(p(
    'El juego recompensa el ahorro con combustible extra, incentivando el habito sin '
    'forzarlo. El nino entiende que puede decidir libremente como usa su dinero, pero '
    'que guardar tiene sus beneficios tangibles dentro del juego.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 7. PREGUNTAS
# ════════════════════════════════════════════════════════════
story += sh('7. Preguntas — Quiz de Educacion Financiera', BLUE)
story.append(p(
    'La pantalla de Preguntas es el modulo de aprendizaje mas directo. Presenta '
    'preguntas de cultura financiera adaptadas a la edad, con respuestas multiples '
    'y explicaciones educativas despues de cada respuesta.'))
story.append(Paragraph('Flujo de una sesion', S_SUB))
story.append(t2([
    ['Paso',                '¿Que ocurre?'],
    ['1. Ingreso',          'El jugador entra al edificio de Preguntas desde el mapa.'],
    ['2. Pregunta',         'Aparece una tarjeta con la pregunta y 2 a 4 opciones de respuesta.'],
    ['3. Seleccion',        'El jugador elige una opcion. Las opciones se bloquean inmediatamente.'],
    ['4. Retroalimentacion','La respuesta correcta se ilumina verde y la incorrecta roja. Blink celebra o anima al jugador.'],
    ['5. Explicacion',      'Caja educativa con la explicacion del concepto financiero.'],
    ['6. Siguiente',        'Boton para avanzar a la siguiente pregunta.'],
    ['7. Resumen',          'Al terminar el mazo: medalla segun desempeno (oro 100%, plata 75%+, bronce 50%+, libro menos de 50%).'],
], w1=PW*0.28, hbg=BLUE))
story.append(Spacer(1, 8))
story.append(Paragraph('Tipos de preguntas', S_SUB))
story.append(bul('Opcion multiple: 4 respuestas, una correcta.'))
story.append(bul('Verdadero / Falso: 2 respuestas.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Recompensas', S_SUB))
story.append(t2([
    ['Resultado',               'Recompensa'],
    ['Respuesta correcta',      '+5 a +15 monedas Blink + XP'],
    ['Respuesta incorrecta',    'Sin penalizacion — solo muestra la explicacion educativa'],
    ['Terminar mazo completo',  'Medalla segun desempeno'],
], hbg=BLUE))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 8. TRABAJOS
# ════════════════════════════════════════════════════════════
story += sh('8. Trabajos — Mini-Economia de Materiales', FOREST_GREEN)
story.append(p(
    'Los Trabajos son encargos de personajes del mundo. El jugador necesita colectar '
    'ciertos materiales (comprados en la Tienda) y los combina para recibir monedas, '
    'XP e items especiales.'))
story.append(Paragraph('Concepto educativo', S_SUB))
story.append(p(
    'Esta mecanica introduce inversion y retorno: el jugador gasta monedas en materiales '
    '(costo) esperando una recompensa mayor (retorno). Si el trabajo da mas monedas que '
    'costaron los materiales, hay ganancia; si no, fue una mala decision de inversion.'))
story.append(Paragraph('Flujo de un trabajo', S_SUB))
story.append(t2([
    ['Paso',              'Descripcion'],
    ['1. Ver lista',      'Pantalla con tarjetas de todos los trabajos disponibles del mundo.'],
    ['2. Revisar materiales', 'Cada tarjeta muestra los materiales necesarios en verde si ya los tienes o en rojo si te faltan.'],
    ['3. Ir a Tienda',    'Si faltan materiales el boton dice "Ve a la Tienda". El jugador va a comprar lo necesario y regresa.'],
    ['4. Realizar',       'Con todos los materiales completos: dialogo de confirmacion, consumo de materiales y entrega de recompensa.'],
    ['5. Celebracion',    'Dialogo animado con monedas, XP e item especial (si aplica). El personaje del mundo agradece al jugador.'],
], w1=PW*0.28, hbg=FOREST_GREEN))
story.append(Spacer(1, 6))
story.append(t2([
    ['Tipo de recompensa', 'Descripcion'],
    ['Monedas Blink',     'Entre 20 y 60 monedas segun la dificultad del trabajo.'],
    ['XP',               'Entre 10 y 25 puntos de experiencia.'],
    ['Item especial',    'Algunos trabajos otorgan un item coleccionable adicional (opcional).'],
], hbg=FOREST_GREEN))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 9. MISIONES
# ════════════════════════════════════════════════════════════
story += sh('9. Misiones — Retos con Objetivos', PURPLE)
story.append(p(
    'Las Misiones son retos con metas especificas que unen las diferentes actividades '
    'del juego en un objetivo comun, incentivando al jugador a explorar todas las secciones.'))
story.append(Paragraph('Tipos de objetivos de mision', S_SUB))
story.append(t2([
    ['Tipo de objetivo',       'Descripcion'],
    ['Completar quizzes',      'Responder N preguntas correctamente.'],
    ['Completar trabajos',     'Realizar N trabajos del mapa.'],
    ['Comprar en la Tienda',   'Comprar N items de la tienda.'],
], hbg=PURPLE))
story.append(Spacer(1, 8))
story.append(Paragraph('Estructura de una mision', S_SUB))
story.append(bul('Nombre descriptivo y emoji identificativo.'))
story.append(bul('Uno o varios objetivos con contador de progreso visible.'))
story.append(bul('Recompensa al completar: monedas, XP y/o item especial.'))
story.append(bul('Estado visual claro: en progreso o completado.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Flujo', S_SUB))
story.append(t2([
    ['Paso',          'Descripcion'],
    ['1. Ver misiones', 'Pantalla con todas las misiones disponibles, cada una con barra de progreso.'],
    ['2. Avanzar',    'Al realizar trabajos, preguntas o compras el contador de la mision avanza automaticamente.'],
    ['3. Completar',  'Al alcanzar todos los objetivos se otorga la recompensa de forma automatica.'],
], w1=PW*0.28, hbg=PURPLE))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 10. TIENDA
# ════════════════════════════════════════════════════════════
story += sh('10. Tienda — Compra de Materiales e Items', ORANGE)
story.append(p(
    'La Tienda es el punto de abastecimiento del jugador. Aqui compra los materiales '
    'necesarios para completar trabajos y los cosmeticos para personalizar a Blink.'))
story.append(Paragraph('Que hay en la Tienda', S_SUB))
story.append(bul('Items de uso en Trabajos: maderas, minerales, ingredientes, etc.'))
story.append(bul('Cada item tiene nombre, emoji descriptivo y precio en monedas Blink.'))
story.append(bul('El jugador ve cuantas unidades tiene en su inventario en ese momento.'))
story.append(bul('Se pueden comprar en cantidad variable segun necesidad.'))
story.append(bul('Seccion de cosmeticos: sombreros, trajes y accesorios para Blink.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Concepto educativo', S_SUB))
story.append(p(
    'El jugador debe balancear su presupuesto: comprar demasiado sin trabajo disponible '
    'desperdicia monedas. Comprar poco impide completar trabajos. Esta mecanica introduce '
    'la planificacion de compras y el uso consciente del dinero.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 11. MERCADO
# ════════════════════════════════════════════════════════════
story += sh('11. Mercado — Comercio entre Jugadores', TEAL)
story.append(p(
    'El Mercado es el espacio de comercio entre jugadores donde pueden comprar y vender '
    'items entre si. Introduce los conceptos de oferta, demanda y precio de mercado.'))
story.append(Paragraph('Las 3 pestanas del Mercado', S_SUB))
story.append(t2([
    ['Pestana',       'Descripcion'],
    ['Mi Inventario', 'Lista de todos los items que el jugador tiene. Puede poner cualquiera a la venta directamente desde aqui.'],
    ['Mi Tienda',     'Items que el jugador tiene publicados para vender. Puede tener hasta 10 items activos. Ve el precio y las unidades de cada uno.'],
    ['Explorar',      'Catalogo de items publicados por otros jugadores. Puede buscar lo que necesita y comprarlo con sus monedas Blink.'],
], hbg=TEAL))
story.append(Spacer(1, 8))
story.append(Paragraph('Flujo de venta', S_SUB))
story.append(bul('El jugador elige un item de su inventario y lo pone a la venta.'))
story.append(bul('Establece el precio que desea en monedas Blink.'))
story.append(bul('El item aparece en "Explorar" para que otros jugadores lo vean.'))
story.append(bul('Cuando alguien lo compra, las monedas se acreditan automaticamente al vendedor.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Concepto educativo', S_SUB))
story.append(p(
    'El nino aprende que puede generar ingresos vendiendo sus recursos, que el precio '
    'lo define el mercado (si nadie compra, esta muy caro), y que existe diferencia '
    'entre el valor percibido y el valor de mercado.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 12. COMBUSTIBLE
# ════════════════════════════════════════════════════════════
story += sh('12. Combustible y Rachas', ORANGE)
story.append(p(
    'El Combustible es una barra de progreso que representa la "energia" del cohete de '
    'Blink. Es el mecanismo principal de engagement diario: incentiva al jugador a abrir '
    'la app cada dia para mantener su progreso activo.'))
story.append(Paragraph('Como sube el combustible', S_SUB))
story.append(t2([
    ['Accion',                                    'Combustible ganado'],
    ['Entrar a la app cualquier dia',             '+10% de combustible (actividad diaria)'],
    ['Depositar en Guardar o Banco Estelar',      '+5% adicional por operacion'],
    ['Depositar en Gastar',                       '+3% adicional por operacion'],
    ['Cobrar el salario semanal',                 '+porcentaje segun la cantidad cobrada'],
], hbg=ORANGE))
story.append(Spacer(1, 8))
story.append(Paragraph('Rachas (streaks)', S_SUB))
story.append(p(
    'El juego registra cuantos dias consecutivos el jugador abre la app. Una racha '
    'activa es un indicador de habito positivo. Si el jugador no entra un dia, '
    'la racha se resetea desde cero.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Combustible al 100% en el mundo Espacial', S_SUB))
story.append(p(
    'Cuando la barra llega al 100% en el mundo espacial, se desbloquea el Hangar '
    'de Despegue con recompensas especiales (detallado en la seccion 4).'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 13. SALARIO
# ════════════════════════════════════════════════════════════
story += sh('13. Salario Semanal — Mesada Digital', PURPLE)
story.append(p(
    'El Salario Semanal es una funcion exclusiva para los padres que simula una mesada '
    'digital. El padre asigna una cantidad fija de monedas Blink que se ponen disponibles '
    'para el nino una vez a la semana.'))
story.append(t2([
    ['Aspecto',              'Detalle'],
    ['Quien lo configura',   'El padre, desde su Panel de Control.'],
    ['Cantidad',             'Entre 20 y 35 monedas Blink por semana (configurable por el padre).'],
    ['Frecuencia',           'Una vez por semana.'],
    ['Como lo cobra el nino','Aparece un chip animado "Cobrar" en el HUD del mapa. Al tocarlo, dialogo de celebracion con las monedas y el combustible obtenidos.'],
    ['Si ya se cobro',       'El sistema detecta el cobro de la semana y muestra un aviso informativo amable.'],
    ['Combustible',          'Cobrar el salario tambien suma puntos de combustible al nino como incentivo.'],
], hbg=PURPLE))
story.append(Spacer(1, 8))
story.append(Paragraph('Concepto educativo', S_SUB))
story.append(p(
    'El nino aprende que el dinero puede llegar de forma periodica y que debe esperar '
    'a la semana siguiente para recibir mas. Esto introduce la planificacion de ingresos '
    'y la espera como parte normal del manejo del dinero.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 14. PANEL DEL PADRE
# ════════════════════════════════════════════════════════════
story += sh('14. Panel del Padre — Control Parental', DARK_BG)
story.append(p(
    'Los padres tienen una experiencia completamente diferente a la de los ninos. '
    'En lugar de un mapa de juego, ven un panel de supervision y gestion.'))
story.append(Paragraph('Pantalla principal del padre', S_SUB))
story.append(bul('Fondo animado con estrellas (estetica especial para adultos).'))
story.append(bul('Panel izquierdo: saldo del padre en monedas Blink.'))
story.append(bul('Panel derecho: lista de hijos vinculados con su nivel y progreso.'))
story.append(bul('Boton "Agregar hijo" para vincular nuevas cuentas de ninos.'))
story.append(bul('Campana de notificaciones con contador de mensajes sin leer.'))
story.append(Spacer(1, 6))
story.append(Paragraph('Detalle de cada hijo', S_SUB))
story.append(t2([
    ['Seccion',          'Informacion mostrada'],
    ['Panel izquierdo',  'Avatar de Blink, nivel actual, barra de XP, estadisticas (monedas totales, XP, misiones completadas), medallas obtenidas.'],
    ['Panel derecho',    'Actividad reciente: misiones en las que participo el hijo, con fecha, monedas y XP ganados en cada una.'],
    ['Accion principal', 'Boton "Enviar monedas" para transferir monedas Blink del padre al hijo de forma inmediata.'],
], hbg=DARK_BG))
story.append(Spacer(1, 8))
story.append(Paragraph('Envio de monedas (padre a hijo)', S_SUB))
story.append(bul('El padre elige la cantidad: 10, 25, 50, 100, 200 o 500 monedas.'))
story.append(bul('Se muestra el saldo disponible del padre para evitar sobregiros.'))
story.append(bul('La transferencia es atomica y 100% segura, validada completamente en el servidor.'))
story.append(bul('El hijo recibe una notificacion en su campana en tiempo real.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 15. TUTORIAL
# ════════════════════════════════════════════════════════════
story += sh('15. Tutorial de Bienvenida', BLUE)
story.append(p(
    'El tutorial es el primer contacto del jugador con Blinkids. Aparece una sola vez '
    'al registrarse y no se puede omitir, garantizando que todos los jugadores conozcan '
    'las mecanicas basicas.'))
story.append(Paragraph('Los 4 pasos del tutorial', S_SUB))
story.append(t3([
    ['Paso', 'Titulo',         'Que explica Blink'],
    ['1',    'Hola! Soy Blink','Presentacion del personaje guia. Blink ayudara al jugador a aprender a ahorrar, invertir y manejar sus monedas.'],
    ['2',    'El Bosque Magico','Introduce el primer mundo. Explica el mapa, los 6 edificios y que hay misiones por completar.'],
    ['3',    'Tu Bolsa',       'Introduce las categorias de la bolsa: Ahorro, Inversion, Emergencia, Gastos y Metas.'],
    ['4',    'A por ello!',    'Motivacion final. Invita a completar trabajos, preguntas y misiones para crecer junto a Blink.'],
], hbg=BLUE))
story.append(Spacer(1, 8))
story.append(Paragraph('Al completar el tutorial', S_SUB))
story.append(bul('+200 monedas Blink de regalo (starter coins para comenzar a explorar).'))
story.append(bul('Acceso completo al mapa del Bosque Magico.'))
story.append(bul('El progreso queda guardado en la nube — el tutorial no se repite aunque se reinstale la app.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 16. COSMÉTICOS Y MEDALLAS
# ════════════════════════════════════════════════════════════
story += sh('16. Cosmeticos y Medallas', FOREST_GREEN)
story.append(Paragraph('Cosmeticos', S_SUB))
story.append(p(
    'Los cosmeticos son accesorios visuales que el jugador puede aplicar al personaje '
    'Blink. No afectan la mecanica del juego; son recompensas de personalizacion para '
    'premiar el progreso y hacer la experiencia mas personal.'))
story.append(bul('Se compran con monedas Blink en la seccion de cosmeticos de la Tienda.'))
story.append(bul('Algunos son exclusivos de logros especiales (ejemplo: Traje Dorado del Hangar).'))
story.append(bul('El jugador puede ver y cambiar sus cosmeticos activos desde su perfil en cualquier momento.'))
story.append(Spacer(1, 8))
story.append(Paragraph('Medallas (Badges)', S_SUB))
story.append(p(
    'Las medallas son logros permanentes que el jugador acumula a lo largo del juego. '
    'Son un historial de hitos que el jugador ha alcanzado.'))
story.append(bul('Cada medalla tiene nombre, descripcion y emoji propio.'))
story.append(bul('Se muestran en el perfil del hijo y son visibles para el padre desde su panel.'))
story.append(bul('Ejemplos: primera mision completada, primera semana de racha activa, primer trabajo realizado.'))
story.append(PageBreak())

# ════════════════════════════════════════════════════════════
# 17. SEGURIDAD
# ════════════════════════════════════════════════════════════
story += sh('17. Seguridad y Privacidad', DARK_BG)
story.append(p(
    'Blinkids fue disenado desde el inicio con los ninos como prioridad. Los siguientes '
    'principios de diseno garantizan una experiencia completamente segura para menores.'))
story.append(t2([
    ['Principio',             'Implementacion'],
    ['Sin dinero real',       'Los ninos NUNCA ven ni manejan dinero real. Solo monedas Blink ficticias sin valor economico.'],
    ['Transacciones seguras', 'Toda transferencia pasa por una funcion en el servidor que valida el vinculo familiar, evitando fraudes y duplicaciones.'],
    ['Sin clave admin en app', 'La app usa unicamente la clave publica anonima de la API. La clave de administrador nunca esta en el dispositivo del nino.'],
    ['Control parental',      'Los padres controlan el salario, ven toda la actividad y envian monedas. El nino no puede gastar mas de lo que tiene.'],
    ['Sin chat libre',        'No existe mensajeria directa entre jugadores. La interaccion es solo a traves del mercado de items (transaccional, no social).'],
    ['Datos minimos',         'Solo se solicita nombre de usuario y correo electronico al registrarse. Sin ubicacion ni datos personales sensibles.'],
    ['Atomicidad financiera', 'Las transacciones son atomicas: si algo falla durante una transferencia, el sistema revierte todo automaticamente. No se pierde ni duplica ninguna moneda.'],
], hbg=DARK_BG))
story.append(Spacer(1, 14))

# ════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ════════════════════════════════════════════════════════════
story += sh('Resumen — Mapa de Flujos de Blinkids', TEAL)
story.append(p('El siguiente diagrama muestra como se conectan todos los modulos del juego:'))
story.append(Spacer(1, 8))
for line in [
    '  REGISTRO / LOGIN',
    '       |',
    '  TUTORIAL (Blink x 4 pasos)  ->  +200 monedas Blink de bienvenida',
    '       |',
    '  MAPA DEL MUNDO  [Bosque Magico | Galaxia Espacial]',
    '       |  HUD: [Avatar+Nivel+XP]  [Combustible]  [Salario chip]  [Monedas]',
    '       |',
    '       +-- PREGUNTAS  ---------->  +Monedas  +XP  +Progreso Mision',
    '       |',
    '       +-- TRABAJOS  ---------->  Requiere Materiales  ->  +Monedas +XP +Items',
    '       |         <-- TIENDA  <--  Compra de Materiales / Cosmeticos',
    '       |',
    '       +-- MISIONES  ---------->  Objetivos multiples  ->  +Monedas +XP +Items',
    '       |',
    '       +-- MERCADO  ----------->  Vender Items propios / Comprar de otros',
    '       |',
    '       +-- MI BOLSA  ---------->  Distribuir [Guardar | Banco Estelar | Gastar]',
    '       |                          +Combustible por ahorrar',
    '       |',
    '       +-- PANEL PADRE  ------->  Ver actividad / Enviar monedas / Salario',
    '       |',
    '  COMBUSTIBLE = 100%  ->  HANGAR  ->  +50 monedas + Traje Dorado + Reinicio',
]: story.append(Paragraph(line, S_MAP))

story.append(Spacer(1, 14))
story.append(Paragraph('Tabla resumen de todos los modulos', S_SUB))
story.append(t4([
    ['Modulo',       'Entra con',           'Sale con',               'Concepto financiero'],
    ['Tutorial',     '—',                   '+200 monedas',           'Introduccion general'],
    ['Preguntas',    'Tiempo',              '+Monedas +XP',           'Conocimiento financiero'],
    ['Trabajos',     'Materiales',          '+Monedas +XP',           'Inversion y retorno'],
    ['Tienda',       'Monedas',             'Materiales / Cosmeticos','Gasto planificado'],
    ['Mercado',      'Items / Monedas',     '+Monedas / Items',       'Oferta, demanda, precio'],
    ['Misiones',     'Actividad en el juego','+Monedas +XP',          'Objetivos y metas'],
    ['Mi Bolsa',     'Monedas',             'Monedas guardadas',      'Ahorro y presupuesto'],
    ['Salario',      'Una vez / semana',    '+Monedas +Combustible',  'Ingreso periodico'],
    ['Hangar',       '100% combustible',    '+50 monedas +Traje',     'Logro de meta grande'],
], [PW*0.14, PW*0.19, PW*0.24, PW*0.43], hbg=TEAL))

story.append(Spacer(1, 20))
story.append(HRFlowable(width='100%', color=GREY_MED, thickness=1,
    spaceBefore=6, spaceAfter=8))
story.append(Paragraph(
    'Blinkids — Documento de Producto  |  Confidencial  |  Junio 2026', S_FT))

doc.build(story)
print(f'PDF generado: {OUTPUT}')
