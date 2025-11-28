-- SCRIPT PARA AGREGAR TABLA REGIONES Y CAMPO ID_REGION
-- Base de datos: bigdata
-- Propósito: Completar requerimeintos 6, 7, 8, 9 del instructivo

-- =========================================================================
-- 1. CREAR TABLA REGIONES
-- =========================================================================
CREATE TABLE IF NOT EXISTS regiones (
    id_region INTEGER PRIMARY KEY,
    nombre_region VARCHAR(50) NOT NULL,
    descripcion VARCHAR(255)
);

-- Insertar datos de regiones
INSERT INTO regiones (id_region, nombre_region, descripcion) VALUES
(1, 'Eje Cafetero', 'Región cafetera tradicional de Colombia'),
(2, 'Centro Oriente', 'Región central y oriental del país'),
(3, 'Centro Sur', 'Región central y sur del país'),
(4, 'Caribe', 'Región costa caribe atlántica'),
(5, 'Llano', 'Región de los llanos orientales'),
(6, 'Pacífico', 'Región costa pacífica occidental');

-- =========================================================================
-- 2. AGREGAR CAMPO ID_REGION A TABLA OPERACIONES
-- =========================================================================
ALTER TABLE operaciones 
ADD COLUMN IF NOT EXISTS id_region INTEGER;

-- Agregar restricción de clave foránea
ALTER TABLE operaciones 
ADD CONSTRAINT fk_operaciones_region 
FOREIGN KEY (id_region) REFERENCES regiones(id_region);

-- =========================================================================
-- 3. ACTUALIZAR ID_REGION EN OPERACIONES BASADO EN DEPARTAMENTOS
-- =========================================================================
UPDATE operaciones 
SET id_region = d.codigo_region
FROM departamentos d 
WHERE operaciones.id_departamento = d.id_departamento;

-- =========================================================================
-- 4. VERIFICACIONES
-- =========================================================================

-- Verificar que todas las operaciones tienen id_region
SELECT 
    'Operaciones sin id_region' as verificacion,
    COUNT(*) as cantidad
FROM operaciones 
WHERE id_region IS NULL;

-- Verificar distribución por región
SELECT 
    r.nombre_region,
    COUNT(o.id_registro) as operaciones
FROM regiones r
LEFT JOIN operaciones o ON r.id_region = o.id_region
GROUP BY r.id_region, r.nombre_region
ORDER BY operaciones DESC;

-- Verificar integridad referencial
SELECT 
    'Integridad referencial OK' as verificacion,
    COUNT(*) as operaciones_validas
FROM operaciones o
JOIN regiones r ON o.id_region = r.id_region;

COMMIT;