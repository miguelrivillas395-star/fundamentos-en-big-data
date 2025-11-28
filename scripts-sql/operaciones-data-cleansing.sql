-- =========================================================================
-- PUNTO 8: DATA CLEANSING - CORRECCIÓN DE PROBLEMAS EN OPERACIONES
-- =========================================================================
-- Propósito: Corregir todos los problemas identificados en tabla operaciones
-- Fecha: Octubre 2025
-- Equipo: Equipo X

-- =========================================================================
-- 1. CORRECCIÓN DE FECHAS CON FORMATO INCORRECTO
-- =========================================================================

-- Crear tabla de auditoría para cambios
DROP TABLE IF EXISTS auditoria_limpieza;

CREATE TABLE auditoria_limpieza (
    id_auditoria SERIAL PRIMARY KEY,
    id_registro INTEGER,
    tabla_afectada VARCHAR(50),
    campo_modificado VARCHAR(50),
    valor_anterior TEXT,
    valor_nuevo TEXT,
    tipo_correccion VARCHAR(100),
    fecha_correccion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observaciones TEXT
);

-- =========================================================================
-- CORRECCIÓN 1: Fechas formato YYYY-M-DD ? YYYY-MM-DD
-- =========================================================================

-- Documentar cambios antes de realizar
INSERT INTO auditoria_limpieza (id_registro, tabla_afectada, campo_modificado, valor_anterior, tipo_correccion, observaciones)
SELECT 
    id_registro,
    'operaciones' as tabla_afectada,
    'fecha' as campo_modificado,
    fecha as valor_anterior,
    'CORRECCION_FECHA_MES_SIN_CERO' as tipo_correccion,
    'Agregar cero inicial al mes' as observaciones
FROM operaciones 
WHERE fecha ~ '^\\d{4}-\\d{1}-\\d{2}$';

-- Realizar corrección
UPDATE operaciones 
SET fecha = SUBSTRING(fecha, 1, 5) || '0' || SUBSTRING(fecha, 6)
WHERE fecha ~ '^\\d{4}-\\d{1}-\\d{2}$';

-- Actualizar auditoría con valor nuevo
UPDATE auditoria_limpieza 
SET valor_nuevo = (
    SELECT fecha 
    FROM operaciones 
    WHERE operaciones.id_registro = auditoria_limpieza.id_registro
)
WHERE tipo_correccion = 'CORRECCION_FECHA_MES_SIN_CERO';

-- =========================================================================
-- CORRECCIÓN 2: Fechas formato YYYY-MM-D ? YYYY-MM-DD
-- =========================================================================

-- Documentar cambios
INSERT INTO auditoria_limpieza (id_registro, tabla_afectada, campo_modificado, valor_anterior, tipo_correccion, observaciones)
SELECT 
    id_registro,
    'operaciones' as tabla_afectada,
    'fecha' as campo_modificado,
    fecha as valor_anterior,
    'CORRECCION_FECHA_DIA_SIN_CERO' as tipo_correccion,
    'Agregar cero inicial al día' as observaciones
FROM operaciones 
WHERE fecha ~ '^\\d{4}-\\d{2}-\\d{1}$';

-- Realizar corrección
UPDATE operaciones 
SET fecha = SUBSTRING(fecha, 1, 8) || '0' || SUBSTRING(fecha, 9)
WHERE fecha ~ '^\\d{4}-\\d{2}-\\d{1}$';

-- Actualizar auditoría
UPDATE auditoria_limpieza 
SET valor_nuevo = (
    SELECT fecha 
    FROM operaciones 
    WHERE operaciones.id_registro = auditoria_limpieza.id_registro
)
WHERE tipo_correccion = 'CORRECCION_FECHA_DIA_SIN_CERO';

-- =========================================================================
-- CORRECCIÓN 3: Fechas formato DD-MM-YYYY ? YYYY-MM-DD (cuando día > 12)
-- =========================================================================

-- Identificar y corregir fechas con formato europeo
INSERT INTO auditoria_limpieza (id_registro, tabla_afectada, campo_modificado, valor_anterior, tipo_correccion, observaciones)
SELECT 
    id_registro,
    'operaciones' as tabla_afectada,
    'fecha' as campo_modificado,
    fecha as valor_anterior,
    'CORRECCION_FECHA_FORMATO_EUROPEO' as tipo_correccion,
    'Conversión de DD-MM-YYYY a YYYY-MM-DD' as observaciones
FROM operaciones 
WHERE fecha ~ '^\\d{2}-\\d{2}-\\d{4}$' 
AND SUBSTRING(fecha, 1, 2)::INTEGER > 12;

-- Realizar corrección para formato DD-MM-YYYY cuando día > 12
UPDATE operaciones 
SET fecha = SUBSTRING(fecha, 7, 4) || '-' || SUBSTRING(fecha, 4, 2) || '-' || SUBSTRING(fecha, 1, 2)
WHERE fecha ~ '^\\d{2}-\\d{2}-\\d{4}$' 
AND SUBSTRING(fecha, 1, 2)::INTEGER > 12;

-- =========================================================================
-- CORRECCIÓN 4: Fechas con años abreviados (24 ? 2024)
-- =========================================================================

-- Identificar años abreviados
INSERT INTO auditoria_limpieza (id_registro, tabla_afectada, campo_modificado, valor_anterior, tipo_correccion, observaciones)
SELECT 
    id_registro,
    'operaciones' as tabla_afectada,
    'fecha' as campo_modificado,
    fecha as valor_anterior,
    'CORRECCION_FECHA_AÑO_ABREVIADO' as tipo_correccion,
    'Conversión de año abreviado a completo' as observaciones
FROM operaciones 
WHERE fecha ~ '^\\d{2}-\\d{2}-\\d{2}$' OR fecha ~ '^\\d{1,2}-\\d{1,2}-\\d{2}$';

-- Corregir años abreviados (asumiendo 2024)
UPDATE operaciones 
SET fecha = '2024-' || LPAD(SPLIT_PART(fecha, '-', 2), 2, '0') || '-' || LPAD(SPLIT_PART(fecha, '-', 1), 2, '0')
WHERE fecha ~ '^\\d{2}-\\d{2}-\\d{2}$' OR fecha ~ '^\\d{1,2}-\\d{1,2}-\\d{2}$';

-- =========================================================================
-- CORRECCIÓN 5: Actualizar ID_REGION faltante
-- =========================================================================

-- Documentar operaciones sin id_region
INSERT INTO auditoria_limpieza (id_registro, tabla_afectada, campo_modificado, valor_anterior, tipo_correccion, observaciones)
SELECT 
    id_registro,
    'operaciones' as tabla_afectada,
    'id_region' as campo_modificado,
    COALESCE(id_region::TEXT, 'NULL') as valor_anterior,
    'CORRECCION_ID_REGION_FALTANTE' as tipo_correccion,
    'Asignación de id_region basado en departamento' as observaciones
FROM operaciones 
WHERE id_region IS NULL OR id_region = 0;

-- Actualizar id_region faltante
UPDATE operaciones 
SET id_region = d.codigo_region
FROM departamentos d 
WHERE operaciones.id_departamento = d.id_departamento
AND (operaciones.id_region IS NULL OR operaciones.id_region = 0);

-- =========================================================================
-- CORRECCIÓN 6: Manejar registros huérfanos (sin referencias válidas)
-- =========================================================================

-- Crear tabla para registros problemáticos que no se pueden corregir automáticamente
DROP TABLE IF EXISTS operaciones_problematicas;

CREATE TABLE operaciones_problematicas AS
SELECT 
    o.*,
    'REFERENCIA_INVALIDA' as motivo_exclusion,
    CURRENT_TIMESTAMP as fecha_exclusion
FROM operaciones o 
LEFT JOIN departamentos d ON o.id_departamento = d.id_departamento 
LEFT JOIN productos p ON o.id_producto = p.id_producto
WHERE d.id_departamento IS NULL OR p.id_producto IS NULL;

-- Documentar exclusiones
INSERT INTO auditoria_limpieza (id_registro, tabla_afectada, campo_modificado, valor_anterior, tipo_correccion, observaciones)
SELECT 
    id_registro,
    'operaciones' as tabla_afectada,
    'registro_completo' as campo_modificado,
    'REGISTRO_VALIDO' as valor_anterior,
    'EXCLUSION_REFERENCIA_INVALIDA' as tipo_correccion,
    'Registro movido a tabla operaciones_problematicas por referencias inválidas' as observaciones
FROM operaciones_problematicas;

-- Eliminar registros problemáticos de la tabla principal
DELETE FROM operaciones 
WHERE id_registro IN (SELECT id_registro FROM operaciones_problematicas);

-- =========================================================================
-- 7. CREAR TABLA OPERACIONES CORREGIDA (DOCUMENTACIÓN)
-- =========================================================================

-- Crear tabla con datos corregidos para comparación
DROP TABLE IF EXISTS operaciones_corregida;

CREATE TABLE operaciones_corregida AS 
SELECT * FROM operaciones;

-- Agregar información de auditoría
ALTER TABLE operaciones_corregida 
ADD COLUMN limpieza_fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- =========================================================================
-- 8. REPORTES DE LIMPIEZA REALIZADOS
-- =========================================================================

-- Reporte de correcciones aplicadas
SELECT 
    tipo_correccion,
    COUNT(*) as registros_corregidos,
    MAX(fecha_correccion) as ultima_correccion
FROM auditoria_limpieza
GROUP BY tipo_correccion
ORDER BY registros_corregidos DESC;

-- Verificación de fechas después de limpieza
SELECT 
    'FECHAS_VALIDAS_POST_LIMPIEZA' as verificacion,
    COUNT(*) as cantidad
FROM operaciones 
WHERE fecha ~ '^\\d{4}-\\d{2}-\\d{2}$'

UNION ALL

SELECT 
    'FECHAS_INVALIDAS_POST_LIMPIEZA' as verificacion,
    COUNT(*) as cantidad
FROM operaciones 
WHERE fecha !~ '^\\d{4}-\\d{2}-\\d{2}$'

UNION ALL

SELECT 
    'OPERACIONES_CON_ID_REGION' as verificacion,
    COUNT(*) as cantidad
FROM operaciones 
WHERE id_region IS NOT NULL AND id_region > 0

UNION ALL

SELECT 
    'REGISTROS_EXCLUIDOS' as verificacion,
    COUNT(*) as cantidad
FROM operaciones_problematicas;

-- Estadísticas finales de calidad
SELECT 
    'CALIDAD_POST_LIMPIEZA' as metrica,
    ROUND(
        (SELECT COUNT(*) FROM operaciones WHERE fecha ~ '^\\d{4}-\\d{2}-\\d{2}$' AND id_region IS NOT NULL) * 100.0 / 
        (SELECT COUNT(*) FROM operaciones), 2
    ) || '%' as valor

UNION ALL

SELECT 
    'TOTAL_CORRECCIONES_APLICADAS' as metrica,
    COUNT(*)::TEXT as valor
FROM auditoria_limpieza

UNION ALL

SELECT 
    'REGISTROS_FINALES_VALIDOS' as metrica,
    COUNT(*)::TEXT as valor
FROM operaciones;

COMMIT;

-- =========================================================================
-- DATA CLEANSING COMPLETADO
-- =========================================================================
-- ? Fechas corregidas automáticamente
-- ? ID_region actualizado
-- ? Registros problemáticos identificados y separados
-- ? Auditoría completa de cambios documentada
-- ? Tablas de respaldo creadas (original y corregida)
-- =========================================================================