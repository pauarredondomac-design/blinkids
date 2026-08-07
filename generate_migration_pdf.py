"""
Genera Blinkids_Guia_Migracion.pdf en la raíz del repo.
Lista las cuentas de terceros que el equipo receptor debe registrar/tomar
control, y el estado de preparación del proyecto para la entrega.
"""
from fpdf import FPDF
from fpdf.enums import XPos, YPos
import datetime

DARK_BG    = (13, 18, 48)
ACCENT     = (99, 102, 241)      # indigo  -  Supabase/general
GREEN      = (16, 185, 129)      # ok
RED        = (220, 38, 38)       # critico
AMBER      = (217, 119, 6)       # advertencia
MID_GRAY   = (100, 116, 139)
WHITE      = (255, 255, 255)
LIGHT_BG   = (241, 245, 255)
DARK_TEXT  = (15, 23, 42)
CODE_BG    = (238, 240, 246)

PAGE_W = 210
MARGIN = 16
CONTENT_W = PAGE_W - 2 * MARGIN


class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=True, margin=20)

    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*DARK_BG)
        self.rect(0, 0, PAGE_W, 12, 'F')
        self.set_font('Helvetica', 'B', 8)
        self.set_text_color(*WHITE)
        self.set_y(3)
        self.cell(0, 6, 'Blinkids  |  Guia de Migracion y Entrega', align='C')
        self.set_text_color(*DARK_TEXT)
        self.ln(10)

    def footer(self):
        self.set_y(-14)
        self.set_font('Helvetica', '', 7)
        self.set_text_color(*MID_GRAY)
        self.cell(0, 6,
                   f'Pagina {self.page_no()}  |  Generado {datetime.date.today().strftime("%d/%m/%Y")}',
                   align='C')


def h1(pdf, text):
    pdf.set_font('Helvetica', 'B', 18)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(0, 12, text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.set_draw_color(*ACCENT)
    pdf.set_line_width(0.8)
    pdf.line(MARGIN, pdf.get_y(), MARGIN + 40, pdf.get_y())
    pdf.ln(6)


def h2(pdf, text, color=ACCENT):
    pdf.set_font('Helvetica', 'B', 12)
    pdf.set_text_color(*color)
    pdf.cell(0, 9, text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.set_text_color(*DARK_TEXT)


def body(pdf, text, size=10, gap=5):
    pdf.set_font('Helvetica', '', size)
    pdf.set_text_color(*DARK_TEXT)
    pdf.multi_cell(CONTENT_W, gap, text)


def code_line(pdf, label, value):
    pdf.set_font('Helvetica', 'B', 9.5)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(38, 6, label)
    pdf.set_font('Courier', '', 9.5)
    pdf.set_fill_color(*CODE_BG)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(0, 6, ' ' + value + ' ', fill=True, new_x=XPos.LMARGIN, new_y=YPos.NEXT)


def bullet(pdf, text, size=9.5, indent=6):
    pdf.set_font('Helvetica', '', size)
    pdf.set_text_color(*DARK_TEXT)
    x0 = pdf.get_x()
    pdf.cell(indent, 5.5, '-')
    pdf.multi_cell(CONTENT_W - indent, 5.5, text)
    pdf.set_x(x0)


def account_card(pdf, num, title, why, current, action, tag, tag_color):
    # tarjeta con borde izquierdo de color
    y0 = pdf.get_y()
    pdf.set_font('Helvetica', 'B', 12.5)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(0, 8, f'{num}. {title}', new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    pdf.set_font('Helvetica', 'B', 8)
    pdf.set_fill_color(*tag_color)
    pdf.set_text_color(*WHITE)
    w = pdf.get_string_width(tag) + 6
    pdf.cell(w, 6, tag, fill=True, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.ln(2)

    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*MID_GRAY)
    pdf.cell(0, 5.5, 'Para que sirve en el proyecto:', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    body(pdf, why, size=9.5, gap=5)
    pdf.ln(1)

    if current:
        pdf.set_font('Helvetica', 'B', 9)
        pdf.set_text_color(*MID_GRAY)
        pdf.cell(0, 5.5, 'Dato actual encontrado en el proyecto:', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
        for label, value in current:
            code_line(pdf, label, value)
        pdf.ln(1)

    pdf.set_font('Helvetica', 'B', 9)
    pdf.set_text_color(*MID_GRAY)
    pdf.cell(0, 5.5, 'Que tiene que hacer el equipo que recibe el proyecto:', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    for a in action:
        bullet(pdf, a)

    pdf.ln(4)
    y1 = pdf.get_y()
    pdf.set_draw_color(220, 224, 235)
    pdf.line(MARGIN, y1, PAGE_W - MARGIN, y1)
    pdf.ln(5)


def finding(pdf, level, level_color, title, detail):
    pdf.set_font('Helvetica', 'B', 8.5)
    pdf.set_fill_color(*level_color)
    pdf.set_text_color(*WHITE)
    w = pdf.get_string_width(level) + 6
    pdf.cell(w, 6, level, fill=True, align='C')
    pdf.set_text_color(*DARK_TEXT)
    pdf.set_font('Helvetica', 'B', 10.5)
    pdf.cell(4)
    pdf.multi_cell(0, 6, title)
    pdf.ln(1)
    body(pdf, detail, size=9.5, gap=5)
    pdf.ln(4)


pdf = PDF()

# ── Portada ──────────────────────────────────────────────────────────────────
pdf.add_page()
pdf.set_fill_color(*DARK_BG)
pdf.rect(0, 0, PAGE_W, 90, 'F')
pdf.set_y(28)
pdf.set_font('Helvetica', 'B', 30)
pdf.set_text_color(*WHITE)
pdf.cell(0, 14, 'Blinkids', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.set_font('Helvetica', '', 14)
pdf.cell(0, 10, 'Guia de Migracion y Cuentas Necesarias', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.ln(4)
pdf.set_font('Helvetica', '', 10)
pdf.set_text_color(200, 205, 230)
pdf.cell(0, 6, f'Preparado para la entrega del proyecto', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.cell(0, 6, datetime.date.today().strftime('%d de %B de %Y'), align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.set_y(100)
pdf.set_text_color(*DARK_TEXT)
pdf.set_font('Helvetica', '', 11)
body(pdf,
     'Este documento tiene dos partes: primero, la lista de cuentas/servicios externos '
     'de los que depende la app y que el equipo que la reciba debe registrar o tomar '
     'control; segundo, una revision del estado del proyecto de cara a la entrega, con '
     'los puntos que hay que resolver antes o justo despues de migrarlo.',
     size=11, gap=6)
pdf.ln(4)
pdf.set_font('Helvetica', 'B', 10)
pdf.set_text_color(*ACCENT)
pdf.cell(0, 7, 'Resumen rapido', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.set_font('Helvetica', '', 10)
pdf.set_text_color(*DARK_TEXT)
for line in [
    '6 cuentas/servicios externos identificados (Supabase, GitHub, Google, OneSignal, '
    'Google Play, Apple Developer).',
    '2 puntos criticos que deben resolverse antes de entregar: cambios locales sin subir '
    'a GitHub, y el build de Android firmado con la llave de debug.',
    'No se encontraron llaves secretas expuestas en el codigo de la app (la anon key de '
    'Supabase y el App ID de OneSignal estan disenados para ir embebidos en el cliente).',
]:
    bullet(pdf, line, size=10)

# ── Seccion 1: Cuentas ────────────────────────────────────────────────────────
pdf.add_page()
h1(pdf, '1. Cuentas que deben registrarse')
body(pdf,
     'Por cada servicio: para que se usa, el dato que ya existe en el proyecto (para '
     'identificarlo), y los pasos concretos para tomar control de el.', size=9.5, gap=5)
pdf.ln(3)

account_card(
    pdf, 1, 'Supabase (backend, base de datos, autenticacion)',
    'Es todo el backend de la app: base de datos Postgres, autenticacion de usuarios '
    '(padres e hijos), reglas de seguridad (RLS), funciones RPC que mueven monedas '
    'entre billeteras, y una funcion Edge que envia las notificaciones push.',
    [('Proyecto:', 'mzwvazjofbdelsejxoqi'),
     ('URL:', 'https://mzwvazjofbdelsejxoqi.supabase.co')],
    ['Crear una cuenta en supabase.com con el correo del nuevo equipo/organizacion.',
     'Pedirle al dueno actual que agregue esa cuenta como miembro del proyecto '
     '(Project Settings > Team), o que transfiera el proyecto completo a la nueva '
     'organizacion.',
     'Una vez con acceso, revisar Authentication > Providers > Google: ahi estan '
     'guardadas las credenciales de Google OAuth (client ID/secret)  -  no estan en el '
     'codigo de la app.',
     'Revisar Edge Functions > send-push > Secrets: debe tener configuradas '
     'ONESIGNAL_APP_ID y ONESIGNAL_REST_API_KEY (ver punto 4).',
     'Si se decide NO quedarse con este mismo proyecto de Supabase, hay un backup '
     'completo de esquema/funciones/politicas/datos en la carpeta supabase_backup/ '
     'del repositorio, mas la carpeta supabase/ con las migraciones aplicadas.'],
    'CRITICO', RED,
)

account_card(
    pdf, 2, 'GitHub (repositorio de codigo)',
    'Ahi vive todo el codigo fuente de la app (Flutter) y el historial de cambios.',
    [('Repositorio:', 'github.com/merinogomez17-sudo/blinkids_v1'),
     ('Rama principal:', 'main')],
    ['Crear una cuenta/organizacion en GitHub para el nuevo equipo.',
     'Pedirle al dueno actual que agregue esa cuenta como colaborador, o que '
     'transfiera el repositorio (Settings > Transfer ownership) a la nueva cuenta.',
     'Alternativa mas simple si no se necesita el historial completo: hacer un fork '
     'o clonar y subir a un repositorio nuevo propio.'],
    'CRITICO', RED,
)

account_card(
    pdf, 3, 'Google Cloud Console (inicio de sesion con Google)',
    'La app permite iniciar sesion con una cuenta de Google. Las credenciales OAuth '
    '(Client ID y Client Secret) que hacen esto posible NO estan en el codigo de la '
    'app: estan configuradas dentro de Supabase (Authentication > Providers > Google), '
    'pero esas credenciales fueron creadas en un proyecto de Google Cloud aparte.',
    None,
    ['Pedir acceso al proyecto de Google Cloud donde se crearon esas credenciales '
     '(el dueno actual deberia saber cual es), o crear uno nuevo si se prefiere '
     'empezar de cero.',
     'Si se crea uno nuevo: hay que generar nuevas credenciales OAuth 2.0, configurar '
     'la pantalla de consentimiento, y agregar el redirect URI que da Supabase, y '
     'luego actualizar esas credenciales en Supabase (Authentication > Providers > '
     'Google).',
     'El deep link que usa la app para volver del login (blinkids://callback) ya '
     'esta configurado en Android e iOS  -  no hay que tocarlo salvo que cambien el '
     'identificador de la app.'],
    'IMPORTANTE', AMBER,
)

account_card(
    pdf, 4, 'OneSignal (notificaciones push)',
    'Envia las notificaciones push a los celulares (por ejemplo, avisarle al papa '
    'que el hijo marco una tarea como hecha). El App ID esta embebido en el codigo '
    'de la app (no es secreto, funciona igual que una llave publica), pero la cuenta '
    'de OneSignal en si y la REST API Key (esa si es secreta) no estan en el repo.',
    [('App ID:', '34dd4e8c-d60d-4ee8-8251-c0179f6a87c5')],
    ['Pedir que agreguen la cuenta del nuevo equipo como colaborador en el dashboard '
     'de OneSignal (onesignal.com) de esa app, o crear una app nueva si prefieren '
     'empezar de cero.',
     'Si crean una app nueva en OneSignal: hay que reemplazar el App ID en el codigo '
     '(lib/data/services/push_notification_service.dart) por el nuevo, y volver a '
     'configurar las credenciales de push de Android/iOS dentro de OneSignal.',
     'De cualquier forma, hay que configurar en Supabase (Edge Functions > send-push '
     '> Secrets) las variables ONESIGNAL_APP_ID y ONESIGNAL_REST_API_KEY  -  sin eso, '
     'la funcion que manda los push falla en silencio.'],
    'IMPORTANTE', AMBER,
)

pdf.add_page()

account_card(
    pdf, 5, 'Google Play Console (publicar en Android)',
    'Para subir la app a la Play Store (o repartir betas cerradas) hace falta una '
    'cuenta de desarrollador de Google Play.',
    [('Identificador de la app (package):', 'com.blinkids.app')],
    ['Crear una cuenta en play.google.com/console (costo unico de USD 25).',
     'IMPORTANTE: antes de poder publicar hay que generar una llave de firma de '
     'release real  -  ahorita mismo el build de release esta firmado con la llave '
     'de debug (ver seccion 2, hallazgo critico). Sin resolver esto no se puede '
     'subir un release valido a la Play Store.',
     'Si ya existe una cuenta de Play Console con esta app publicada o en pruebas, '
     'pedir que agreguen al nuevo equipo como usuario en Users and permissions.'],
    'IMPORTANTE', AMBER,
)

account_card(
    pdf, 6, 'Apple Developer Program (publicar en iOS)',
    'Necesario unicamente si se va a distribuir la app en iOS/App Store. Sirve para '
    'generar certificados de firma y perfiles de aprovisionamiento.',
    [('Bundle ID:', 'com.blinkids.app')],
    ['Crear o pedir acceso a una cuenta en developer.apple.com (costo USD 99/ano).',
     'Configurar el Bundle ID com.blinkids.app en ese equipo de desarrollo.',
     'Si se usan notificaciones push en iOS, tambien hay que subir el certificado '
     'APNs correspondiente dentro del dashboard de OneSignal.',
     'Este punto se puede posponer si la entrega del miercoles es solo para Android.'],
    'OPCIONAL', MID_GRAY,
)

# ── Seccion 2: Revision de migracion ─────────────────────────────────────────
pdf.add_page()
h1(pdf, '2. Revision de preparacion para la migracion')
body(pdf,
     'Se reviso el estado del repositorio, la configuracion de firma de Android, y '
     'las alertas de seguridad de Supabase. Esto es lo que se encontro, de mas a '
     'menos urgente.', size=9.5, gap=5)
pdf.ln(3)

finding(pdf, 'CRITICO', RED,
        'Hay cambios locales que todavia no se subieron a GitHub',
        'El repositorio local tiene 98 archivos con cambios (81 modificados, 16 nuevos, '
        '1 eliminado) que nunca se hicieron commit. Esto incluye TODO el trabajo de '
        'unificacion visual, el sistema de misiones de papa con confirmacion, los '
        'popups de la app, y varios arreglos de esta sesion. Si se entrega el repositorio '
        'tal como esta en GitHub ahorita, la persona que lo reciba NO va a tener nada de '
        'esto  -  solo va a tener el ultimo commit ("Backup de Supabase..."). '
        'Hace falta revisar los cambios, hacer commit y hacer push a origin/main antes '
        'de la entrega del miercoles.')

finding(pdf, 'CRITICO', RED,
        'El build de Android release esta firmado con la llave de debug',
        'En android/app/build.gradle.kts, la seccion buildTypes > release usa '
        'signingConfig = signingConfigs.getByName("debug"). Esto sirve para probar '
        'rapido durante el desarrollo, pero un release firmado asi NO se puede subir '
        'a Google Play, y si alguna vez se reinstala sobre una version firmada '
        'distinta, Android bloquea la actualizacion. Antes de publicar hay que generar '
        'un keystore de verdad (keytool -genkey), guardarlo en un lugar seguro (fuera '
        'del repositorio), y configurar signingConfigs > release con esos datos.')

finding(pdf, 'ADVERTENCIA', AMBER,
        'Proteccion contra contrasenas filtradas esta desactivada',
        'Supabase Auth tiene una opcion para rechazar contrasenas que aparecen en '
        'bases de datos de filtraciones conocidas (HaveIBeenPwned) y esta apagada. '
        'Se activa en Authentication > Policies del dashboard de Supabase, sin tocar '
        'codigo. No es bloqueante para la entrega, pero es recomendable activarla '
        'antes de lanzar a produccion con usuarios reales.')

finding(pdf, 'OK', GREEN,
        'No se encontraron llaves secretas expuestas en el codigo',
        'La anon key de Supabase y el App ID de OneSignal SI estan escritos en el '
        'codigo de la app, pero eso es correcto y esperado: ambos estan disenados '
        'para viajar dentro de la app (la seguridad real la da Row Level Security '
        'en Supabase, no ocultar esos valores). Las llaves que si son secretas '
        '(Google OAuth secret, OneSignal REST API Key) estan guardadas del lado del '
        'servidor (Supabase), no en el repositorio.')

finding(pdf, 'OK', GREEN,
        'El diseno de seguridad de la base de datos esta bien planteado',
        'Se revisaron las alertas automaticas de seguridad de Supabase: no hay '
        'ninguna de nivel error, solo advertencias esperables para este tipo de '
        'arquitectura (todas las escrituras sensibles pasan por funciones RPC con '
        'validaciones propias, en vez de dejar que el cliente escriba directo a las '
        'tablas). No se necesita accion antes de la entrega.')

finding(pdf, 'OK', GREEN,
        'No se encontraron otras cuentas o servicios de terceros ocultos',
        'Se reviso el pubspec.yaml, la configuracion de Android/iOS, y el codigo en '
        'busca de Firebase, servicios de pago, analytics externos (Mixpanel, '
        'Amplitude) u otros servicios  -  no se encontro ninguno. El sistema de '
        'analytics del panel de administracion esta construido enteramente con '
        'funciones propias dentro de Supabase, sin depender de un servicio externo.')

pdf.ln(2)
h2(pdf, 'Checklist para antes del miercoles')
for item in [
    'Revisar y hacer commit + push de los cambios locales pendientes.',
    'Confirmar con el dueno actual como se va a transferir el acceso a Supabase y '
    'GitHub (agregar colaborador vs. transferir cuenta).',
    'Anotar en algun lugar seguro (no en el repo) las credenciales de OneSignal y '
    'Google Cloud que use el nuevo equipo.',
    'Si la entrega incluye un APK para instalar directo (no via Play Store), no es '
    'bloqueante seguir firmando con la llave de debug  -  pero si se va a publicar en '
    'Play Store, hay que resolver el keystore de release antes.',
]:
    bullet(pdf, item, size=10)

pdf.output('Blinkids_Guia_Migracion.pdf')
print('OK: Blinkids_Guia_Migracion.pdf generado')
