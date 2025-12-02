
# FROTATO

## High-Level Design Document (HLD)
**Nombre del Proyecto:** Frotato

**Género:** Roguelite Arena Shooter / Asimétrico (3v1)

**Plataforma Objetivo:** PC (Steam), consolas (futuro), Steam Deck.

**Referencia Visual/Mecánica:** Brotato, Vampire Survivors, Among Us (estilo visual simple), Crawl.

---

## 1. Resumen Ejecutivo (Executive Summary)
Un juego de acción frenética donde **3 Héroes** deben sobrevivir en una arena cerrada (la "mazmorra") durante un número fijo de oleadas. Un cuarto jugador, el **Overlord (Dueño de la Mazmorra)**, no lucha directamente al principio, sino que gestiona la economía del mal: invoca monstruos, coloca trampas y diseña al Jefe Final.

El ciclo de juego se divide en **Fase de Acción** (combate) y **Fase de Tienda** (mejoras), aplicable tanto para los héroes como para el villano.

---

## 2. Jugabilidad y Mecánicas (Core Gameplay)

### 2.1. Los Héroes (3 Jugadores)
La jugabilidad es idéntica a *Brotato*:
* **Control:** Movimiento manual (WASD/Stick). El disparo es **automático** (con opción de apuntado manual para ciertas armas).
* **Objetivo:** Sobrevivir al tiempo límite de la oleada (ej. 60 segundos) y eliminar enemigos para recoger "Materiales" (oro/xp).
* **Clases:** Al inicio eligen un arquetipo (ej. "El Tanque", "El Veloz", "El Mago", "El Loco").
* **Sinergia:** A diferencia de Brotato (single player), aquí las auras pasivas son clave (ej. "Los aliados cerca de ti ganan +5 HP reg").

### 2.2. El Overlord (1 Jugador)
La jugabilidad es una mezcla de *Tower Defense* inverso y gestión de recursos:
* **Perspectiva:** Vista aérea completa de la arena.
* **Recurso:** "Miedo" o "Sangre" (se genera con el tiempo o cuando los héroes reciben daño).
* **Acciones durante la oleada:**
    * **Spawn:** Invocar grupos de enemigos en puntos específicos.
    * **Trampas:** Activar pinchos, lluvias de flechas o áreas de veneno.
    * **Interferencia:** Bloquear temporalmente la visión de un jugador o separar al grupo con muros temporales.

### 2.3. La Tienda (Fase de Descanso)
Entre oleadas, el juego se pausa y todos van a la tienda (20-30 segundos).

| Héroes (Compran con Oro recolectado) | Overlord (Compra con "Lágrimas" de los héroes) |
| :--- | :--- |
| **Estadísticas:** +HP, +Daño, +Rango. | **Horda:** +Velocidad de movimiento, +Daño base de enemigos. |
| **Armas:** Combinar armas iguales para subir nivel. | **Unidades:** Desbloquear enemigos "Élite" o especiales. |
| **Objetos:** Reliquias pasivas. | **Eventos:** Comprar "Lluvia de meteoritos" para la siguiente ronda. |
| **Curación:** Gastar oro para recuperar vida. | **EL BOSS FINAL:** Comprar habilidades para el avatar final. |

### 2.4. El Final Boss (Clímax)
En la última oleada (ej. Oleada 20), el Overlord deja de "invocar" y **toma el control directo** de un Boss gigante que ha ido personalizando durante la partida (ej. le puso mucha vida, o un ataque láser, o velocidad extrema).

---

## 3. Estructura del Bucle de Juego (Game Loop)

1.  **Lobby:** Selección de personajes (3 Héroes vs 1 Overlord).
2.  **Inicio:** Los héroes entran en la arena (Sala 1).
3.  **Fase de Acción (60s):**
    * Héroes matan bichos -> Ganan Oro/XP.
    * Overlord gasta energía -> Envía bichos -> Gana puntos si hiere a héroes.
4.  **Fase de Tienda:** Todos gastan sus monedas.
5.  **Repetir:** Pasos 3 y 4 (La dificultad escala).
6.  **Boss Fight:** El Overlord se materializa.
7.  **Fin de Partida:** Ganan los Héroes si matan al Boss; Gana el Overlord si mata a los 3 héroes.

---

## 4. Arquitectura Técnica (Technical Stack)

### 4.1. Motor de Juego

* **Godot**. Muy ligero, genial para 2D, sin costes de licencia.

### 4.2. Networking (Multijugador)
Dado que es acción rápida, la latencia es crítica.
* **Arquitectura:** Cliente-Servidor o P2P con Host-Relay (Relay es más barato).
* **Solución Sugerida (Godot):** **https://docs.godotengine.org/es/4.x/classes/class_enetmultiplayerpeer.html** .
* **Sincronización:**
    * La posición de los enemigos la dicta el Host (Overlord).
    * Los disparos y movimientos de los héroes se predicen en el cliente.

### 4.3. Inteligencia Artificial (IA)
* La IA de los monstruos debe ser simple ("Boids" o "Pathfinding" básico hacia el héroe más cercano) para permitir cientos de unidades en pantalla sin lag.

---

## 5. Arte y Audio (Art & Audio Direction)

### 5.1. Estilo Visual
* **Estilo:** "Hand-drawn ugly-cute" (como *The Binding of Isaac* o *Brotato*). Personajes tipo "patata" o formas simples con extremidades flotantes.
* **Legibilidad:** Es vital que los proyectiles de los enemigos sean de un color muy diferente (ej. Rojo brillante) al de los héroes (ej. Azul/Verde) para evitar confusión visual en el caos.

### 5.2. Audio
* **Música:** Chiptune acelerado o Metal progresivo (aumenta el tempo cuando queda poco tiempo).
* **SFX:** Sonidos "jugosos" (juicy) al golpear enemigos. Feedback auditivo claro cuando un jugador pierde vida.

---

## 6. UI/UX (Interfaz de Usuario)

* **HUD Héroes:** Barras de vida claras sobre la cabeza. Indicadores de munición/cooldown.
* **HUD Overlord:**
    * Barra de "Recurso de Invocación".
    * Barra de cartas/unidades disponibles (Drag & Drop o Hotkeys 1-4).
    * Mini-mapa táctico.

---

## 7. Desafíos y Riesgos

1.  **Balanceo Asimétrico:** Es lo más difícil. Si el Overlord es muy fuerte, los 3 jugadores se frustran. Si es muy débil, se aburre.
    * *Solución:* Sistema de "Rubber banding" (si los héroes van perdiendo, la tienda les ofrece descuentos; si el Overlord va perdiendo, gana recursos más rápido).
2.  **Rendimiento de Red:** Sincronizar 300 enemigos en pantalla para 4 jugadores es costoso.
    * *Solución:* No sincronizar cada movimiento de cada enemigo pequeño. Sincronizar solo el "spawner" y usar lógica determinista, o agrupar enemigos en "hordas" que se mueven como una sola entidad lógica.
