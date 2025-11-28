# DICCIONARIO DE DATOS
## Base de Datos: BIGDATA - Sistema de Gestión de Operaciones Comerciales

### TABLA: DEPARTAMENTOS
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| **id_departamento** | INTEGER | 4 bytes | PRIMARY KEY, NOT NULL | Identificador único del departamento. Formato: 57XX (57 = Colombia + código DANE) |
| codigo_dane | VARCHAR | 10 | NOT NULL | Código oficial DANE del departamento |
| nombre | VARCHAR | 255 | NOT NULL | Nombre oficial del departamento |
| codigo_region | INTEGER | 4 bytes | NOT NULL | Código de región (1=Eje Cafetero, 2=Centro Oriente, 3=Centro Sur, 4=Caribe, 5=Llano, 6=Pacífico) |

**Índices:**
- PRIMARY KEY: id_departamento
- INDEX: codigo_dane (para búsquedas por código DANE)

**Relaciones:**
- 1:N con MUNICIPIOS (Un departamento tiene muchos municipios)
- 1:N con OPERACIONES (Un departamento participa en muchas operaciones)
- 1:1 con TAMANIO (Un departamento tiene una caracterización de tamaño)

---

### TABLA: MUNICIPIOS
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| **id_municipio** | INTEGER | 4 bytes | PRIMARY KEY, NOT NULL | Identificador único del municipio. Formato secuencial por departamento |
| **id_departamento** | INTEGER | 4 bytes | FOREIGN KEY, NOT NULL | Referencia al departamento al que pertenece |
| codigo_dane | VARCHAR | 10 | NOT NULL | Código oficial DANE del municipio |
| nombre | VARCHAR | 255 | NOT NULL | Nombre oficial del municipio |

**Índices:**
- PRIMARY KEY: id_municipio
- FOREIGN KEY: id_departamento ? DEPARTAMENTOS(id_departamento)
- INDEX: codigo_dane (para búsquedas por código DANE)

**Relaciones:**
- N:1 con DEPARTAMENTOS (Muchos municipios pertenecen a un departamento)
- 1:N con OPERACIONES (Un municipio registra muchas operaciones)

---

### TABLA: PRODUCTOS
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| **id_producto** | INTEGER | 4 bytes | PRIMARY KEY, NOT NULL | Identificador único del producto |
| nombre | VARCHAR | 255 | NOT NULL | Nombre comercial del producto |
| precio | DECIMAL | 10,2 | NOT NULL, CHECK (precio > 0) | Precio unitario del producto en pesos colombianos |

**Datos Iniciales:**
1. Coca-Cola - $3,500
2. Pepsi - $3,200
3. Sprite - $3,000
4. Fanta - $2,800

**Índices:**
- PRIMARY KEY: id_producto

**Relaciones:**
- 1:N con OPERACIONES (Un producto interviene en muchas operaciones)

---

### TABLA: OPERACIONES
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| **id_registro** | INTEGER | 4 bytes | PRIMARY KEY, NOT NULL | Identificador único de la operación comercial |
| **id_departamento** | INTEGER | 4 bytes | FOREIGN KEY, NOT NULL | Referencia al departamento donde ocurre la operación |
| **id_municipio** | INTEGER | 4 bytes | FOREIGN KEY, NOT NULL | Referencia al municipio donde ocurre la operación |
| **id_producto** | INTEGER | 4 bytes | FOREIGN KEY, NOT NULL | Referencia al producto de la operación |
| fecha | VARCHAR | 20 | NOT NULL | Fecha de la operación. **PROBLEMA DE CALIDAD**: Formato inconsistente |
| cantidad | INTEGER | 4 bytes | NOT NULL | Cantidad de unidades (positivo=venta, negativo=devolución) |
| estado | CHAR | 1 | NOT NULL, DEFAULT 'F' | Estado de la operación ('F' = Finalizado) |
| **id_region** | INTEGER | 4 bytes | FOREIGN KEY, NULL | Referencia a la región geográfica (AGREGADO POST-ETL) |

**Índices:**
- PRIMARY KEY: id_registro
- FOREIGN KEY: id_departamento ? DEPARTAMENTOS(id_departamento)
- FOREIGN KEY: id_municipio ? MUNICIPIOS(id_municipio)
- FOREIGN KEY: id_producto ? PRODUCTOS(id_producto)
- INDEX: fecha (para consultas por período)

**Relaciones:**
- N:1 con DEPARTAMENTOS (Muchas operaciones pertenecen a un departamento)
- N:1 con MUNICIPIOS (Muchas operaciones pertenecen a un municipio)
- N:1 con PRODUCTOS (Muchas operaciones involucran un producto)
- N:1 con REGIONES (Muchas operaciones pertenecen a una región - AGREGADO POST-ETL)

**PROBLEMA DE CALIDAD DE DATOS:**
- Campo `fecha` almacenado como VARCHAR con formatos inconsistentes
- Ejemplos encontrados: '2024-8-21', '2024-01-19', '2024-11-24'
- **Solución recomendada**: Convertir a tipo DATE y estandarizar formato

---

### TABLA: TAMANIO
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| **id_departamento** | INTEGER | 4 bytes | PRIMARY KEY, FOREIGN KEY, NOT NULL | Referencia al departamento caracterizado |
| nombre_departamento | VARCHAR | 255 | NOT NULL | Nombre del departamento (desnormalizado para reportes) |
| numero_municipios | INTEGER | 4 bytes | NOT NULL, CHECK (numero_municipios > 0) | Cantidad de municipios del departamento |
| total_operaciones | INTEGER | 4 bytes | NOT NULL, CHECK (total_operaciones >= 0) | Total de operaciones registradas |
| categoria_tamanio | VARCHAR | 50 | NOT NULL | Categoría: 'PEQUEÑO', 'MEDIANO', 'GRANDE' |

**Índices:**
- PRIMARY KEY: id_departamento
- FOREIGN KEY: id_departamento ? DEPARTAMENTOS(id_departamento)
- INDEX: categoria_tamanio (para agrupaciones por tamaño)

**Relaciones:**
- 1:1 con DEPARTAMENTOS (Un departamento tiene una caracterización)

**Reglas de Negocio para Categorización:**
- PEQUEÑO: < 20 municipios o < 100 operaciones
- MEDIANO: 20-50 municipios o 100-500 operaciones
- GRANDE: > 50 municipios o > 500 operaciones

---

### TABLA: REGIONES
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| **id_region** | INTEGER | 4 bytes | PRIMARY KEY, NOT NULL | Identificador único de la región geográfica |
| nombre_region | VARCHAR | 100 | NOT NULL | Nombre descriptivo de la región |
| codigo_region | INTEGER | 4 bytes | UNIQUE, NOT NULL | Código numérico de región (1-6) |

**Datos Iniciales:**
1. Eje Cafetero (código: 1)
2. Centro Oriente (código: 2)  
3. Centro Sur (código: 3)
4. Caribe (código: 4)
5. Llano (código: 5)
6. Pacífico (código: 6)

**Índices:**
- PRIMARY KEY: id_region
- UNIQUE: codigo_region

**Relaciones:**
- 1:N con DEPARTAMENTOS (Una región contiene muchos departamentos)
- 1:N con OPERACIONES (Una región registra muchas operaciones)

**Script de Creación:**
```sql
CREATE TABLE regiones (
    id_region SERIAL PRIMARY KEY,
    nombre_region VARCHAR(100) NOT NULL,
    codigo_region INTEGER UNIQUE NOT NULL
);

INSERT INTO regiones (nombre_region, codigo_region) VALUES 
('Eje Cafetero', 1),
('Centro Oriente', 2),
('Centro Sur', 3),
('Caribe', 4),
('Llano', 5),
('Pacífico', 6);
```

---

### TABLA: TEMPORAL
| Campo | Tipo de Dato | Tamaño | Restricciones | Descripción |
|-------|--------------|--------|---------------|-------------|
| nombre_region | VARCHAR | 255 | NULL | Nombre de la región geográfica |
| codigo_dep | VARCHAR | 10 | NULL | Código DANE del departamento |
| departamento | VARCHAR | 255 | NULL | Nombre del departamento |
| codigo_mun | VARCHAR | 10 | NULL | Código DANE del municipio |
| municipio | VARCHAR | 255 | NULL | Nombre del municipio |
| codigo_region | INTEGER | 4 bytes | NULL | Código numérico de región |

**Propósito:** Tabla temporal utilizada durante el proceso ETL para carga masiva de datos geográficos desde archivo CSV.

**Índices:** Ninguno (tabla de uso temporal)

**Relaciones:** No tiene relaciones formales (tabla de staging)

---

### VISTA: VISTA_OPERACIONES
**Propósito:** Vista de análisis que integra todas las tablas para reportes gerenciales.

**Campos calculados:**
- monto_total: cantidad * precio (Monto total de la operación)

**SQL de Definición:**
```sql
CREATE VIEW vista_operaciones AS
SELECT 
    o.id_registro,
    d.nombre AS departamento,
    m.nombre AS municipio,
    p.nombre AS producto,
    o.fecha,
    o.cantidad,
    p.precio,
    (o.cantidad * p.precio) AS monto_total,
    o.estado,
    d.codigo_region
FROM operaciones o
JOIN departamentos d ON o.id_departamento = d.id_departamento
JOIN municipios m ON o.id_municipio = m.id_municipio
JOIN productos p ON o.id_producto = p.id_producto;
```

---

### CÓDIGOS DE REGIÓN
| Código | Región | Descripción |
|--------|--------|-------------|
| 1 | Eje Cafetero | Región cafetera central |
| 2 | Centro Oriente | Región central oriental |
| 3 | Centro Sur | Región central sur |
| 4 | Caribe | Región costa atlántica |
| 5 | Llano | Región de los llanos orientales |
| 6 | Pacífico | Región costa pacífica |

---

### ESTADÍSTICAS DE LA BASE DE DATOS

**Departamentos:** 32 registros
**Municipios:** 1,122 registros
**Productos:** 4 registros (bebidas gaseosas)
**Operaciones:** ~10,000 registros (datos de prueba)

**Volumen de Datos Estimado:**
- Departamentos: ~8 KB
- Municipios: ~280 KB
- Productos: ~1 KB
- Operaciones: ~400 KB
- **Total estimado:** ~689 KB

---

### PROBLEMAS DE CALIDAD IDENTIFICADOS

1. **Formato de fechas inconsistente** en tabla OPERACIONES
   - Algunos registros: '2024-8-21' (mes sin cero)
   - Otros registros: '2024-01-19' (mes con cero)
   - **Impacto:** Dificultad en consultas por rango de fechas

2. **Cantidades negativas** en OPERACIONES
   - Ejemplo: cantidad = -198 (devoluciones)
   - **Validación necesaria:** Verificar lógica de negocio

3. **Desnormalización** en tabla TAMANIO
   - Campo nombre_departamento duplica información
   - **Recomendación:** Evaluar si es necesario por performance

---

---

### MODIFICACIONES POST-ETL REALIZADAS

#### **Script de Modificación de Tabla OPERACIONES:**
```sql
-- Agregar campo id_region a tabla operaciones
ALTER TABLE operaciones 
ADD COLUMN id_region INTEGER;

-- Crear foreign key hacia tabla regiones
ALTER TABLE operaciones 
ADD CONSTRAINT fk_operaciones_region 
FOREIGN KEY (id_region) REFERENCES regiones(id_region);

-- Actualizar valores de id_region basado en departamento
UPDATE operaciones 
SET id_region = (
    SELECT r.id_region 
    FROM regiones r 
    JOIN departamentos d ON d.codigo_region = r.codigo_region 
    WHERE d.id_departamento = operaciones.id_departamento
);
```

#### **Validación Post-Modificación:**
```sql
-- Verificar que las operaciones tienen id_region asignado
SELECT COUNT(*) as total_operaciones,
       COUNT(id_region) as con_region,
       (COUNT(id_region) * 100.0 / COUNT(*)) as porcentaje_completitud
FROM operaciones;
```

---

### CONVENCIONES DE NOMENCLATURA

- **Tablas:** Nombres en plural, minúsculas
- **Campos:** snake_case, descriptivos
- **Claves primarias:** id_[nombre_tabla]
- **Claves foráneas:** Mismo nombre que la PK referenciada
- **Índices:** idx_[tabla]_[campo]
- **Vistas:** vista_[propósito]