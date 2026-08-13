"""
Genera Blinkids_Estado_vs_Acuerdo.pdf en D:\\Blinkids\\Documentacion\\
Compara los 18 entregables del acuerdo real (Cotizacion_MVP_Blink_FQ-2026-004.pdf)
contra el estado actual del codigo: que se realizo, que se modifico en el
camino, que se agrego extra, y que falta. Layout compacto: sin portada
separada y con espaciado minimo entre bloques.
"""
from fpdf import FPDF
from fpdf.enums import XPos, YPos
import datetime

DARK_BG   = (13, 18, 48)
ACCENT    = (99, 102, 241)
GREEN     = (16, 185, 129)
AMBER     = (217, 119, 6)
RED       = (220, 38, 38)
MID_GRAY  = (100, 116, 139)
WHITE     = (255, 255, 255)
DARK_TEXT = (15, 23, 42)

PAGE_W = 210
MARGIN = 13
CONTENT_W = PAGE_W - 2 * MARGIN


class PDF(FPDF):
    def __init__(self):
        super().__init__()
        self.set_auto_page_break(auto=True, margin=10)

    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*DARK_BG)
        self.rect(0, 0, PAGE_W, 9, 'F')
        self.set_font('Helvetica', 'B', 7.5)
        self.set_text_color(*WHITE)
        self.set_y(2)
        self.cell(0, 5, 'Blinkids  |  Estado vs. Acuerdo FQ-2026-004', align='C')
        self.set_text_color(*DARK_TEXT)
        self.ln(7)

    def footer(self):
        self.set_y(-9)
        self.set_font('Helvetica', '', 6.5)
        self.set_text_color(*MID_GRAY)
        self.cell(0, 5,
                   f'Pagina {self.page_no()}  |  Generado {datetime.date.today().strftime("%d/%m/%Y")}',
                   align='C')


def h1(pdf, text):
    pdf.set_font('Helvetica', 'B', 13)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(0, 7, text, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.set_draw_color(*ACCENT)
    pdf.set_line_width(0.6)
    pdf.line(MARGIN, pdf.get_y(), MARGIN + 30, pdf.get_y())
    pdf.ln(2.2)


def tag(pdf, text, color):
    pdf.set_font('Helvetica', 'B', 7.2)
    pdf.set_fill_color(*color)
    pdf.set_text_color(*WHITE)
    w = pdf.get_string_width(text) + 4
    pdf.cell(w, 4.6, text, fill=True, align='C')
    pdf.set_text_color(*DARK_TEXT)


def item(pdf, num, name, status, color, note):
    pdf.set_font('Helvetica', 'B', 9.3)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(7, 5, f'{num}.')
    avail = CONTENT_W - 7
    name_w = pdf.get_string_width(name) + 2
    tag_w = pdf.get_string_width(status) + 4
    if name_w + tag_w > avail:
        pdf.multi_cell(avail, 5, name)
    else:
        pdf.cell(avail - tag_w, 5, name)
        tag(pdf, status, color)
        pdf.ln(5)
    pdf.set_x(MARGIN + 7)
    pdf.set_font('Helvetica', '', 8.3)
    pdf.set_text_color(*MID_GRAY)
    pdf.multi_cell(avail, 3.9, note)
    pdf.set_text_color(*DARK_TEXT)
    pdf.ln(0.6)


def bullet(pdf, text, size=8.5, color=None):
    pdf.set_font('Helvetica', '', size)
    pdf.set_text_color(*(color or DARK_TEXT))
    x0 = pdf.get_x()
    pdf.cell(4.5, 4.1, '-')
    pdf.multi_cell(CONTENT_W - 4.5, 4.1, text)
    pdf.set_x(x0)


def para(pdf, text, size=8.8, gap=3.9):
    pdf.set_font('Helvetica', '', size)
    pdf.set_text_color(*DARK_TEXT)
    pdf.multi_cell(CONTENT_W, gap, text)


_MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
          'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']
_hoy = datetime.date.today()
_fecha_es = f'{_hoy.day} de {_MESES[_hoy.month - 1]} de {_hoy.year}'

pdf = PDF()
pdf.add_page()

# ── Encabezado compacto (sin portada aparte) ──────────────────────────────────
pdf.set_fill_color(*DARK_BG)
pdf.rect(0, 0, PAGE_W, 22, 'F')
pdf.set_y(4)
pdf.set_font('Helvetica', 'B', 15)
pdf.set_text_color(*WHITE)
pdf.cell(0, 7, 'Blinkids - Estado vs. Acuerdo', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.set_font('Helvetica', '', 9)
pdf.cell(0, 5, f'Cotizacion MVP FQ-2026-004 - 18 entregables, 273 h  |  {_fecha_es}',
         align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.set_y(26)
pdf.set_text_color(*DARK_TEXT)
para(pdf,
     'Comparacion entregable por entregable del acuerdo firmado contra el estado real '
     'del codigo, actualizado con los cambios mas recientes (apps de Android e iOS ya '
     'compiladas y subidas -iOS en pruebas de TestFlight-, recuperacion de acceso para '
     'padres e hijos, y varios ajustes de estabilidad reportados durante las pruebas).')
pdf.ln(1.5)

pdf.set_font('Helvetica', 'B', 9)
pdf.cell(18, 4.6, 'Leyenda:')
for label, color in [('REALIZADO', GREEN), ('REALIZADO + EXTRA', ACCENT), ('EN PROGRESO', AMBER), ('FALTA', RED)]:
    tag(pdf, label, color)
    pdf.cell(2.5, 4.6, '')
pdf.ln(7)

pdf.set_font('Helvetica', 'B', 20)
pdf.set_text_color(*GREEN)
pdf.cell(0, 9, '17 de 18 realizados', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.set_font('Helvetica', '', 9)
pdf.set_text_color(*DARK_TEXT)
pdf.cell(0, 5, 'El item 18 (publicacion en tiendas) esta en progreso: ambas apps ya '
         'estan compiladas, firmadas y subidas; falta la publicacion final.',
         align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.ln(4)

# ── Detalle por entregable ────────────────────────────────────────────────────
h1(pdf, 'Detalle por entregable')

item(pdf, 1, 'Arquitectura completa', 'REALIZADO', GREEN,
     'Riverpod + GoRouter en toda la app. Mundo Espacio con 5 estaciones (Banco Estelar, '
     'Trabajos, Misiones, Tienda, Mi Bolsa) mas Marte como meta del Hangar.')

item(pdf, 2, 'Base de datos, seguridad y sincronizacion en tiempo real', 'REALIZADO', GREEN,
     'RLS en las ~40 tablas. Sincronizacion en tiempo real vía Supabase Realtime activa '
     'en billetera y notificaciones: si el papa manda monedas, se aprueba una mision o '
     'cae el interes semanal, el saldo y la campanita se actualizan solos en pantalla '
     'sin salir y volver a entrar. Se puede extender a otras tablas si hace falta.')

item(pdf, 3, 'Registro, inicio de sesion y roles', 'REALIZADO + EXTRA', ACCENT,
     'Registro, login, rol nino/padre y sesion persistente. Extra: recuperacion de '
     'acceso completa para ambos roles -el papa puede restablecer su contrasena por '
     'correo, y puede reiniciar el PIN de su hijo directamente desde su panel-.')

item(pdf, 4, 'Tutorial interactivo de bienvenida', 'REALIZADO', GREEN,
     '4 pantallas animadas y 200 monedas de inicio al completarlo, tal cual se acordo.')

item(pdf, 5, 'Selector de mundos con desbloqueo', 'REALIZADO', GREEN,
     'Mapa de mundos con costo de desbloqueo visible y bloqueo real hasta cumplirlo.')

item(pdf, 6, 'Sistema de misiones con modulo de preguntas', 'REALIZADO', GREEN,
     'Retroalimentacion inmediata y explicacion detallada cuando el nino falla una pregunta.')

item(pdf, 7, 'Modulo de trabajos para construccion', 'REALIZADO', GREEN,
     'Los trabajos piden materiales especificos y pagan monedas, XP y a veces un item o '
     'combustible; el mismo mecanismo desbloquea construcciones en el mundo.')

item(pdf, 8, 'Mi Bolsa: distribucion en categorias', 'REALIZADO + EXTRA', ACCENT,
     'En el documento ya se tacharon "Emergencia" y "Metas", dejando Ahorro/Inversion/'
     'Gastos. Lo implementado cubre eso y agrega una cuarta categoria, "Donar".')

item(pdf, 9, 'Mercado entre jugadores', 'REALIZADO + EXTRA', ACCENT,
     'El documento ya redujo esto a "solo muestra articulos propios, sin logica de venta '
     'o trueque". Se implemento mercado con compra y venta real entre jugadores.')

item(pdf, 10, 'Tienda de accesorios y materiales', 'REALIZADO', GREEN,
      'Catalogo completo de cosmeticos y materiales comprables con monedas del juego.')

item(pdf, 11, 'Panel de padres', 'REALIZADO + EXTRA', ACCENT,
      'Vinculacion, envio de monedas, salario semanal y actividad reciente: completo. '
      'Extra: tareas creadas por el papa con confirmacion en dos pasos antes de pagar.')

item(pdf, 12, 'Notificaciones dentro de la app (tiempo real)', 'REALIZADO', GREEN,
      'La lista y el contador de la campanita ya usan Supabase Realtime: aparecen solas '
      'apenas se crean, sin recargar la pantalla. Ademas, los 4 tipos de push (mision '
      'nueva, ganancias de la bolsa, domingo de pago, inactividad) llegan al celular '
      'aunque la app este cerrada.')

item(pdf, 13, 'Experiencia, niveles e insignias', 'REALIZADO', GREEN,
      'XP por accion, niveles con recompensas progresivas e insignias coleccionables.')

item(pdf, 14, 'Combustible, rachas y despegue a Marte (Hangar)', 'REALIZADO + EXTRA', ACCENT,
      'Racha diaria, combustible acumulable y Hangar con el progreso. Extra: el despegue '
      'tiene una animacion de video real.')

item(pdf, 15, 'Integracion de analitica de uso', 'REALIZADO + EXTRA', ACCENT,
      'Se pedia "eventos clave con visual sencillo". Se construyo ademas un panel tipo '
      'admin con mas de 20 metricas: usuarios activos, embudo, economia, progreso por '
      'mundo, preguntas mas falladas, items mas comprados, etc.')

item(pdf, 16, 'Sistema de cosmeticos para Blink', 'REALIZADO', GREEN,
      'Personalizacion por slots, comprable en la Tienda y visible en todo el juego.')

item(pdf, 17, 'Soporte y seguimiento del testeo', 'REALIZADO', GREEN,
      'En curso de forma activa. Extra: reporte automatico de errores de la app a la '
      'base de datos, sin depender de que el usuario avise.')

pdf.set_draw_color(*RED)
pdf.set_line_width(0.3)
pdf.line(MARGIN, pdf.get_y(), PAGE_W - MARGIN, pdf.get_y())
pdf.ln(1.2)

item(pdf, 18, 'App publicada en Apple Store y Play Store con notificaciones push', 'EN PROGRESO', AMBER,
      'OJO: este documento se contradice a si mismo (la tabla de precios cobra 8h por '
      'esto; la seccion "Lo que NO incluye este MVP" dice que publicar en las tiendas y '
      'el push quedan fuera del MVP). Falta definir cual de las dos aplica. Estado real: '
      'las notificaciones push YA funcionan (probadas, los 4 disparadores confirman '
      'entrega). Android: build de release firmado con llave de produccion, listo para '
      'subir en cuanto se tenga la cuenta de Play Console. iOS: la app ya se compilo, se '
      'firmo con la cuenta de Apple Developer del cliente y esta subida a App Store '
      'Connect, actualmente en pruebas de TestFlight. Falta: completar la ficha de la '
      'tienda (capturas, descripcion, politica de privacidad) en ambas plataformas y '
      'enviar a revision -esto ya no es un tema tecnico, es llenar informacion y '
      'aprobar-.')

# ── Extras y pendientes ────────────────────────────────────────────────────────
h1(pdf, 'Extras implementados (fuera del alcance del acuerdo)')
for line in [
    'Sistema de diseno visual unico y consistente en toda la app.',
    'Blink reacciona con animaciones distintas segun la accion del nino.',
    'Sonido y animacion al recibir monedas en Mi Bolsa.',
    'Reparto proporcional en Mi Bolsa (chips de 10/25/50/100%) en vez de moneda por moneda.',
    'Tareas del papa con confirmacion en dos pasos antes de pagar la recompensa.',
    'Reporte automatico de errores de la app a la base de datos.',
    'Mercado con compra/venta real entre jugadores.',
    'Panel de analitica con mas de 20 metricas de uso, economia y progreso.',
    'Firma de release lista para Google Play (llave de produccion propia).',
    'Notificaciones push reales con 4 disparadores automaticos (mision nueva, ganancias '
    'de la bolsa, domingo de pago, inactividad), probadas y funcionando.',
    'Sincronizacion en tiempo real (Realtime) del saldo de la billetera y de las '
    'notificaciones dentro de la app.',
    'App de iOS compilada, firmada y subida a App Store Connect (TestFlight).',
    'El papa puede reiniciar el PIN de su hijo directamente desde su panel si lo olvida.',
    'Recuperacion de contrasena por correo para la cuenta de los padres.',
    'Boton para silenciar/activar la musica de fondo.',
    'Ronda de ajustes reportados durante pruebas: navegacion que no dejaba regresar, '
    'verificacion de nombre de aventurero repetido antes de crear el PIN, orden de '
    'desbloqueo de la demo, y texto que se veia recortado en pantallas de iPhone.',
    'Icono y pantalla de bienvenida (splash) con el arte final de la marca.',
]:
    bullet(pdf, line)

pdf.ln(2)
h1(pdf, 'Lo que falta')
for line in [
    'Publicacion real en Google Play - falta crear/activar la cuenta de Play Console y '
    'subir el AAB (ya generado y firmado con llave de produccion).',
    'Publicacion real en App Store - el build ya esta en TestFlight; falta completar '
    'la ficha de la app (capturas, descripcion, clasificacion de edad) y enviarla a '
    'revision de Apple.',
    'Definir con el cliente que aplica del item 18: lo que dice la tabla de precios o lo '
    'que dice la seccion "Lo que NO incluye este MVP" (se contradicen entre si).',
]:
    bullet(pdf, line)

# ── Cuentas necesarias para la migracion ──────────────────────────────────────
pdf.add_page()
h1(pdf, 'Cuentas necesarias para la migracion')
para(pdf,
     'Servicios externos de los que depende la app. Si el proyecto se entrega a otro '
     'equipo, o el cliente quiere administrar estas cuentas directamente, esto es lo '
     'que hay que tomar en cuenta por cada uno.')
pdf.ln(1.5)

item(pdf, 1, 'Supabase (base de datos, autenticacion, backend)', 'ACTIVO', GREEN,
     'Todo el backend: base de datos, login de padres e hijos, reglas de seguridad '
     '(RLS) y las funciones que mueven monedas entre billeteras. Proyecto: '
     'mzwvazjofbdelsejxoqi. Para tomar control: crear cuenta en supabase.com y pedir '
     'que agreguen esa cuenta como miembro del proyecto, o transferir el proyecto '
     'completo a la nueva organizacion.')

item(pdf, 2, 'GitHub (repositorio de codigo)', 'ACTIVO', GREEN,
     'github.com/merinogomez17-sudo/blinkids_v1, rama main. Para tomar control: crear '
     'cuenta/organizacion y pedir que agreguen esa cuenta como colaboradora, o '
     'transferir el repositorio.')

item(pdf, 3, 'Google Cloud Console (inicio de sesion con Google)', 'ACTIVO', GREEN,
     'Las credenciales OAuth que permiten "Entrar con Google" viven en un proyecto de '
     'Google Cloud aparte, configuradas dentro de Supabase (no en el codigo de la '
     'app). Para tomar control: pedir acceso a ese proyecto de Google Cloud, o crear '
     'uno nuevo y actualizar las credenciales en Supabase.')

item(pdf, 4, 'OneSignal (notificaciones push)', 'ACTIVO', GREEN,
     'Ya configurado y funcionando: los 4 tipos de push (mision nueva, ganancias de '
     'la bolsa, domingo de pago, inactividad) se prueban y llegan correctamente. Para '
     'tomar control: pedir que agreguen la cuenta nueva como colaboradora en el '
     'dashboard de onesignal.com de esta app.')

item(pdf, 5, 'Google Play Console (publicar en Android)', 'PENDIENTE', RED,
     'Necesaria para subir la app a Play Store. El AAB ya esta generado y firmado '
     'con una llave de produccion propia (no es la de debug), listo para subir en '
     'cuanto se tenga la cuenta. Costo: USD 25 pago unico.')

item(pdf, 6, 'Apple Developer Program (publicar en iOS)', 'ACTIVO - VER NOTA', AMBER,
     'La cuenta ya esta activa, a nombre del cliente, y es la que se uso para subir '
     'el build actual a TestFlight. IMPORTANTE: es una cuenta tipo "Individual", y '
     'Apple no permite que ese tipo de cuenta le de permiso de firma a otra persona '
     'directamente -por eso, para compilar la app, se genero un certificado manual '
     'en vez de agregar al equipo como miembro-. Si quien reciba el proyecto necesita '
     'compilar para iOS, va a tener que repetir ese mismo proceso (o el cliente puede '
     'cambiar su cuenta a tipo "Organizacion", que si permite compartir el permiso de '
     'firma directamente).')

pdf.ln(1)
h2_note = 'Nota general'
pdf.set_font('Helvetica', 'B', 9.3)
pdf.set_text_color(*DARK_TEXT)
pdf.cell(0, 5, h2_note, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
para(pdf,
     'La anon key de Supabase y el App ID de OneSignal SI estan escritos en el codigo '
     'de la app -eso es normal y esperado, ambos estan disenados para viajar dentro '
     'de la app-. Las llaves que si son secretas (contrasena de la base de datos, '
     'REST API Key de OneSignal) estan guardadas del lado del servidor, no en el '
     'repositorio.', size=8.3, gap=3.9)

pdf.output('Blinkids_Estado_vs_Acuerdo.pdf')
print('OK: Blinkids_Estado_vs_Acuerdo.pdf generado')
