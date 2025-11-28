-- =========================================================================
-- PUNTO 8: DATA CLEANSING - BACKUP DE TABLA OPERACIONES ORIGINAL
-- =========================================================================
-- Propósito: Crear respaldo de datos originales antes de limpieza
-- Fecha: Octubre 2025
-- Equipo: Equipo X

-- =========================================================================
-- 1. CREAR TABLA DE BACKUP CON DATOS ORIGINALES
-- =========================================================================
DROP TABLE IF EXISTS operaciones_original;

CREATE TABLE operaciones_original AS 
SELECT * FROM operaciones;

-- Agregar información de auditoría
ALTER TABLE operaciones_original 
ADD COLUMN backup_fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- =========================================================================
-- 2. DOCUMENTAR PROBLEMAS IDENTIFICADOS EN DATOS ORIGINALES
-- =========================================================================

-- Crear tabla para catalogar problemas
DROP TABLE IF EXISTS problemas_calidad_original;

CREATE TABLE problemas_calidad_original (
    id_problema SERIAL PRIMARY KEY,
    id_registro INTEGER,
    tipo_problema VARCHAR(100),
    campo_afectado VARCHAR(50),
    valor_original TEXT,
    descripcion TEXT,
    fecha_identificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 3. INSERTAR PROBLEMAS IDENTIFICADOS
-- =========================================================================

-- Problema 1: Fechas con formato incorrecto
INSERT INTO problemas_calidad_original (id_registro, tipo_problema, campo_afectado, valor_original, descripcion)
SELECT 
    id_registro,
    'FORMATO_FECHA_INCORRECTO' as tipo_problema,
    'fecha' as campo_afectado,
    fecha as valor_original,
    'Fecha no cumple formato YYYY-MM-DD' as descripcion
FROM operaciones_original 
WHERE fecha !~ '^\\d{4}-\\d{2}-\\d{2}$';

-- Problema 2: Operaciones sin departamento válido
INSERT INTO problemas_calidad_original (id_registro, tipo_problema, campo_afectado, valor_original, descripcion)
SELECT 
    o.id_registro,
    'INTEGRIDAD_REFERENCIAL_DEPARTAMENTO' as tipo_problema,
    'id_departamento' as campo_afectado,
    o.id_departamento::TEXT as valor_original,
    'Referencia a departamento inexistente' as descripcion
FROM operaciones_original o 
LEFT JOIN departamentos d ON o.id_departamento = d.id_departamento 
WHERE d.id_departamento IS NULL;

-- Problema 3: Operaciones sin producto válido
INSERT INTO problemas_calidad_original (id_registro, tipo_problema, campo_afectado, valor_original, descripcion)
SELECT 
    o.id_registro,
    'INTEGRIDAD_REFERENCIAL_PRODUCTO' as tipo_problema,
    'id_producto' as campo_afectado,
    o.id_producto::TEXT as valor_original,
    'Referencia a producto inexistente' as descripcion
FROM operaciones_original o 
LEFT JOIN productos p ON o.id_producto = p.id_producto 
WHERE p.id_producto IS NULL;

-- Problema 4: Cantidades negativas (devoluciones)
INSERT INTO problemas_calidad_original (id_registro, tipo_problema, campo_afectado, valor_original, descripcion)
SELECT 
    id_registro,
    'CANTIDAD_NEGATIVA' as tipo_problema,
    'cantidad' as campo_afectado,
    cantidad::TEXT as valor_original,
    'Cantidad negativa - posible devolución' as descripcion
FROM operaciones_original 
WHERE cantidad < 0;

-- Problema 5: Cantidades cero
INSERT INTO problemas_calidad_original (id_registro, tipo_problema, campo_afectado, valor_original, descripcion)
SELECT 
    id_registro,
    'CANTIDAD_CERO' as tipo_problema,
    'cantidad' as campo_afectado,
    cantidad::TEXT as valor_original,
    'Cantidad cero - operación sin movimiento' as descripcion
FROM operaciones_original 
WHERE cantidad = 0;

-- Problema 6: Operaciones sin id_region
INSERT INTO problemas_calidad_original (id_registro, tipo_problema, campo_afectado, valor_original, descripcion)
SELECT 
    id_registro,
    'ID_REGION_NULO' as tipo_problema,
    'id_region' as campo_afectado,
    COALESCE(id_region::TEXT, 'NULL') as valor_original,
    'Campo id_region sin valorizar' as descripcion
FROM operaciones_original 
WHERE id_region IS NULL OR id_region = 0;

-- =========================================================================
-- 4. REPORTE DE PROBLEMAS IDENTIFICADOS
-- =========================================================================

-- Resumen de problemas por tipo
SELECT 
    tipo_problema,
    COUNT(*) as cantidad_registros,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM operaciones_original)), 2) as porcentaje
FROM problemas_calidad_original
GROUP BY tipo_problema
ORDER BY cantidad_registros DESC;

-- Registros con múltiples problemas
SELECT 
    p.id_registro,
    COUNT(*) as numero_problemas,
    STRING_AGG(p.tipo_problema, ', ') as problemas_identificados
FROM problemas_calidad_original p
GROUP BY p.id_registro
HAVING COUNT(*) > 1
ORDER BY numero_problemas DESC;

-- =========================================================================
-- 5. ESTADÍSTICAS FINALES DE CALIDAD ORIGINAL
-- =========================================================================

SELECT 
    'TOTAL_OPERACIONES' as metrica,
    COUNT(*)::TEXT as valor
FROM operaciones_original

UNION ALL

SELECT 
    'REGISTROS_CON_PROBLEMAS' as metrica,
    COUNT(DISTINCT id_registro)::TEXT as valor
FROM problemas_calidad_original

UNION ALL

SELECT 
    'PORCENTAJE_CALIDAD' as metrica,
    ROUND(
        ((SELECT COUNT(*) FROM operaciones_original) - 
         (SELECT COUNT(DISTINCT id_registro) FROM problemas_calidad_original)) * 100.0 / 
        (SELECT COUNT(*) FROM operaciones_original), 2
    )::TEXT || '%' as valor;

COMMIT;

-- =========================================================================
-- BACKUP COMPLETADO
-- =========================================================================
-- Tabla operaciones_original creada con todos los datos originales
-- Tabla problemas_calidad_original creada con catalogación de problemas
-- Reportes de calidad generados
-- =========================================================================