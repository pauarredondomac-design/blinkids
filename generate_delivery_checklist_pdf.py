"""
Genera Blinkids_Checklist_Entregables.pdf en D:\\Blinkids\\Documentacion\\
Compara los 17 entregables de la propuesta original (Presentacion_Blink.pdf,
Bloque 1, FQ-2026-003) contra el estado real del codigo, y lista lo extra
que se implemento sin estar en el alcance original.
"""
from fpdf import FPDF
from fpdf.enums import XPos, YPos
import datetime

DARK_BG   = (13, 18, 48)
ACCENT    = (99, 102, 241)
GREEN     = (16, 185, 129)
AMBER     = (217, 119, 6)
MID_GRAY  = (100, 116, 139)
WHITE     = (255, 255, 255)
DARK_TEXT = (15, 23, 42)

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
        self.cell(0, 6, 'Blinkids  |  Checklist de Entregables - Bloque 1', align='C')
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


def body(pdf, text, size=10, gap=5):
    pdf.set_font('Helvetica', '', size)
    pdf.set_text_color(*DARK_TEXT)
    pdf.multi_cell(CONTENT_W, gap, text)


def bullet(pdf, text, size=9.5, indent=6, color=None):
    pdf.set_font('Helvetica', '', size)
    pdf.set_text_color(*(color or DARK_TEXT))
    x0 = pdf.get_x()
    pdf.cell(indent, 5.5, '-')
    pdf.multi_cell(CONTENT_W - indent, 5.5, text)
    pdf.set_x(x0)


def section_band(pdf, text, color):
    pdf.set_fill_color(*color)
    pdf.set_text_color(*WHITE)
    pdf.set_font('Helvetica', 'B', 10)
    pdf.cell(0, 7, '  ' + text, fill=True, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    pdf.set_text_color(*DARK_TEXT)
    pdf.ln(2)


def item_row(pdf, num, name, status, status_color, note=None):
    pdf.set_font('Helvetica', 'B', 10.5)
    pdf.set_text_color(*DARK_TEXT)
    pdf.cell(8, 6.5, f'{num}.')
    pdf.cell(126, 6.5, name)

    pdf.set_font('Helvetica', 'B', 8.5)
    pdf.set_fill_color(*status_color)
    pdf.set_text_color(*WHITE)
    w = pdf.get_string_width(status) + 5
    pdf.cell(w, 6, status, fill=True, align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)

    if note:
        pdf.set_x(MARGIN + 8)
        pdf.set_font('Helvetica', '', 9)
        pdf.set_text_color(*MID_GRAY)
        pdf.multi_cell(CONTENT_W - 8, 5, note)
    pdf.ln(2)


pdf = PDF()

# ── Portada ──────────────────────────────────────────────────────────────────
pdf.add_page()
pdf.set_fill_color(*DARK_BG)
pdf.rect(0, 0, PAGE_W, 80, 'F')
pdf.set_y(24)
pdf.set_font('Helvetica', 'B', 26)
pdf.set_text_color(*WHITE)
pdf.cell(0, 12, 'Blinkids', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.set_font('Helvetica', '', 13)
pdf.cell(0, 9, 'Checklist de Entregables - Bloque 1 (FQ-2026-003)', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.ln(2)
pdf.set_font('Helvetica', '', 10)
pdf.set_text_color(200, 205, 230)
pdf.cell(0, 6, 'Comparacion contra la propuesta original (17 entregables, 265 h)', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.cell(0, 6, datetime.date.today().strftime('%d de %B de %Y'), align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.set_y(92)
pdf.set_text_color(*DARK_TEXT)
pdf.set_font('Helvetica', 'B', 32)
pdf.set_text_color(*GREEN)
pdf.cell(0, 14, '17 / 17 entregables implementados', align='C', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.ln(4)
pdf.set_font('Helvetica', '', 11)
pdf.set_text_color(*DARK_TEXT)
body(pdf,
     'Se revisaron los 17 entregables del Bloque 1 uno por uno contra el codigo real de '
     'la app. Los 17 estan implementados y funcionando. En 2 de ellos el resultado final '
     'quedo distinto a como se describio originalmente en la propuesta (se explica el '
     'porque en cada uno, mas abajo) - marcados en amarillo. Ademas, se implementaron '
     'varias cosas que no estaban en el alcance original (listadas al final).',
     size=10.5, gap=6)
pdf.ln(3)
pdf.set_font('Helvetica', 'B', 10)
pdf.cell(0, 7, 'Leyenda', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
for label, color in [('COMPLETO', GREEN), ('COMPLETO + EXTRA', ACCENT), ('CON AJUSTE', AMBER)]:
    pdf.set_font('Helvetica', 'B', 8.5)
    pdf.set_fill_color(*color)
    pdf.set_text_color(*WHITE)
    w = pdf.get_string_width(label) + 5
    pdf.cell(w, 6, label, fill=True, align='C')
    pdf.cell(4, 6, '')
pdf.ln(10)

# ── Checklist ─────────────────────────────────────────────────────────────────
pdf.add_page()
h1(pdf, 'Checklist por entregable')

section_band(pdf, 'INFRAESTRUCTURA Y DATOS', ACCENT)
item_row(pdf, 1, 'Arquitectura completa', 'COMPLETO', GREEN,
         'Riverpod (estado global) + GoRouter (navegacion con auth-aware redirects) en '
         'toda la app. Mundo Espacio con 5 estaciones (Banco Estelar, Trabajos, Misiones, '
         'Tienda, Mi Bolsa) + Marte como meta final (Hangar).')
item_row(pdf, 2, 'Base de datos, seguridad y sincronizacion', 'CON AJUSTE', AMBER,
         'PostgreSQL en Supabase con Row Level Security en las ~40 tablas: completo. '
         'La sincronizacion NO usa Realtime Channels (suscripcion en vivo por WebSocket) '
         'como decia la propuesta - en su lugar, cada pantalla recarga sus datos apenas '
         'termina una accion (crear, comprar, confirmar, etc.). En la practica el usuario '
         've la info actualizada igual, solo que no en el instante en que OTRO dispositivo '
         'hace el cambio (ej. si el papa manda monedas mientras el hijo tiene la app '
         'abierta, el hijo la ve al volver a esa pantalla, no al instante). Se puede '
         'agregar Realtime Channels despues si se necesita esa actualizacion instantanea '
         'entre dispositivos.')

section_band(pdf, 'ONBOARDING', ACCENT)
item_row(pdf, 3, 'Registro, inicio de sesion y roles', 'COMPLETO', GREEN,
         'Registro, login, recuperar contrasena, seleccion de rol nino/padre, y sesion '
         'persistente - los 4 confirmados en el codigo.')
item_row(pdf, 4, 'Tutorial interactivo de bienvenida', 'COMPLETO', GREEN,
         '4 pantallas animadas, tal como se propuso. Otorga 200 monedas de inicio al '
         'completarse (confirmado en el codigo).')
item_row(pdf, 5, 'Selector de mundos con desbloqueo', 'COMPLETO', GREEN,
         'Pantalla de mapa de mundos con costo de desbloqueo visible y bloqueo real hasta '
         'cumplir el requisito.')

section_band(pdf, 'MODULOS EDUCATIVOS', ACCENT)
item_row(pdf, 6, 'Sistema de misiones y preguntas', 'COMPLETO', GREEN,
         'Motor de preguntas con retroalimentacion inmediata y campo de explicacion '
         'detallada que se muestra cuando el nino falla.')
item_row(pdf, 7, 'Modulo de trabajos para construccion', 'COMPLETO', GREEN,
         'Los trabajos piden materiales especificos (requirements) y pagan en monedas, '
         'XP y a veces un item o combustible - el mismo mecanismo que desbloquea '
         'construcciones/edificios en el mundo.')

section_band(pdf, 'ECONOMIA', ACCENT)
item_row(pdf, 8, 'Mi Bolsa', 'CON AJUSTE', AMBER,
         'Implementado con 4 categorias (Ahorro, Inversion, Donar, Gastos) en vez de las '
         '5 originales (Ahorro, Inversion, Emergencia, Gastos, Metas). "Metas" quedo '
         'cubierta por el Banco Estelar (el nino elige una meta - bici, consola, etc. - y '
         'ahorra para ella ahi), pero no existe una categoria separada de "Emergencia": '
         'en su lugar hay una de "Donar". Fue una decision de diseno tomada durante el '
         'desarrollo, no un pendiente - si se prefiere el esquema original de 5 '
         'categorias, se puede ajustar.')
item_row(pdf, 9, 'Mercado entre jugadores', 'COMPLETO + EXTRA', ACCENT,
         'La propuesta decia "fase inicial: solo exhibicion". Se implemento compra y '
         'venta real entre jugadores (publicar articulos, explorar el mercado de otros, '
         'comprar) - mas de lo que pedia el alcance original.')
item_row(pdf, 10, 'Tienda de accesorios y materiales', 'COMPLETO', GREEN,
          'Catalogo completo de cosmeticos y materiales comprables con monedas del juego.')
item_row(pdf, 11, 'Panel de padres', 'COMPLETO + EXTRA', ACCENT,
          'Vinculacion con el hijo, envio de monedas, salario semanal automatico y '
          'actividad reciente: todo presente. Extra no pedido originalmente: el papa '
          'puede crear tareas/misiones especificas para el hijo, que quedan pendientes '
          'de confirmacion del papa antes de pagarse (evita que el hijo cobre sin haber '
          'hecho la tarea de verdad).')

pdf.add_page()
section_band(pdf, 'GAMIFICACION Y EXTRAS', ACCENT)
item_row(pdf, 12, 'Notificaciones dentro de la app', 'COMPLETO + EXTRA', ACCENT,
          'Notificaciones dentro de la app: completo. Extra no pedido originalmente: '
          'notificaciones push reales al celular via OneSignal (funcionan aunque la app '
          'este cerrada). Nota: los 4 tipos de push ya estan definidos en la base de '
          'datos pero todavia no estan conectados a los eventos que los disparan '
          'automaticamente (ej. avisar cuando hay una mision nueva) - la funcionalidad '
          'esta lista, falta conectar el disparador en cada pantalla.')
item_row(pdf, 13, 'Experiencia, niveles e insignias', 'COMPLETO', GREEN,
          'XP por accion, niveles con recompensas progresivas, e insignias coleccionables.')
item_row(pdf, 14, 'Combustible, rachas y Hangar', 'COMPLETO + EXTRA', ACCENT,
          'Racha diaria, combustible acumulable, y el Hangar mostrando el progreso. '
          'Extra: el despegue a Marte tiene una animacion de video real, no solo una '
          'ilustracion estatica.')
item_row(pdf, 15, 'Analitica de uso integrada', 'COMPLETO + EXTRA', ACCENT,
          'La propuesta pedia "instrumentacion de eventos clave". Se construyo ademas un '
          'sistema completo de analitica tipo panel de administracion: usuarios activos '
          'diarios, embudo de conversion, desglose de economia, progreso por mundo, '
          'preguntas mas falladas, items mas comprados, y mas - mas de 20 metricas listas '
          'para consultar.')
item_row(pdf, 16, 'Sistema de cosmeticos para Blink', 'COMPLETO', GREEN,
          'Personalizacion de avatar por slots (ropa, botas, accesorios, etc.), comprable '
          'en la Tienda y visible en todo el juego.')
item_row(pdf, 17, 'Soporte y seguimiento del testeo', 'COMPLETO', GREEN,
          'En curso de forma activa - se construyo ademas un sistema de reporte '
          'automatico de errores (los errores de la app se guardan en la base de datos '
          'para poder revisarlos sin depender de que el usuario los reporte a mano).')

# ── Extras ────────────────────────────────────────────────────────────────────
pdf.add_page()
h1(pdf, 'Resumen de lo extra implementado')
body(pdf,
     'Ademas de lo que ya se menciono arriba junto a cada entregable, esto es lo que se '
     'agrego sin estar en el alcance original de la Propuesta FQ-2026-003:', size=10, gap=5)
pdf.ln(2)

for line in [
    'Sistema de diseno visual unico y consistente en toda la app (misma tipografia, '
    'colores, tarjetas, fondos y estilo de botones en Tienda, Vestidor, Trabajos, '
    'Misiones, Mi Bolsa y Banco Estelar).',
    'Blink (el personaje) reacciona con animaciones distintas segun lo que hace el nino: '
    'celebra al comprar, se pone contento al guardar un look nuevo, etc.',
    'Sonido de "cling" con animacion al recibir monedas en Mi Bolsa.',
    'Reparto proporcional de monedas en Mi Bolsa (chips de 10%/25%/50%/100% del saldo '
    'disponible) en vez de repartir moneda por moneda.',
    'Sistema de tareas del papa con confirmacion en dos pasos (el hijo marca "hecho", el '
    'papa confirma y recien ahi se paga) - evita pagos sin verificar.',
    'Reporte automatico de errores de la app a la base de datos, sin depender de que el '
    'usuario avise.',
    'Mercado con compra/venta real entre jugadores, no solo exhibicion.',
    'Notificaciones push reales (OneSignal), ademas de las notificaciones dentro de la app.',
    'Panel de analitica con mas de 20 metricas de uso, economia y progreso.',
    'Firma de release lista para Google Play (llave de produccion propia, ya no la de '
    'pruebas).',
]:
    bullet(pdf, line, size=10)

pdf.ln(4)
pdf.set_font('Helvetica', 'B', 10)
pdf.set_text_color(*AMBER)
pdf.cell(0, 7, 'Los 2 puntos que quedaron distintos a la propuesta original:', new_x=XPos.LMARGIN, new_y=YPos.NEXT)
pdf.set_text_color(*DARK_TEXT)
for line in [
    'Sincronizacion en tiempo real (Realtime Channels): no implementada literalmente - '
    'se usa actualizacion al completar cada accion en vez de push instantaneo entre '
    'dispositivos.',
    'Mi Bolsa: 4 categorias (Ahorro/Inversion/Donar/Gastos) en vez de las 5 originales '
    '(Ahorro/Inversion/Emergencia/Gastos/Metas).',
]:
    bullet(pdf, line, size=10)

pdf.output('Blinkids_Checklist_Entregables.pdf')
print('OK: Blinkids_Checklist_Entregables.pdf generado')
