import psycopg2

def data_cleansing_simplificado():
    """Ejecuta data cleansing simplificado y efectivo"""
    try:
        conn = psycopg2.connect(
            host="localhost",
            port="5432",
            database="bigdata",
            user="postgres",
            password="postgres"
        )
        cursor = conn.cursor()
        
        print("=== DATA CLEANSING SIMPLIFICADO ===")
        
        # PASO 1: Crear backup si no existe
        print("\\n?? Creando backup...")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS operaciones_original AS 
            SELECT * FROM operaciones;
        """)
        conn.commit()
        print("? Backup creado")
        
        # PASO 2: Identificar problemas con fechas
        print("\\n?? Identificando problemas de fechas...")
        
        # Usar SIMILAR TO en lugar de expresiones regulares complejas
        cursor.execute("""
            SELECT COUNT(*) FROM operaciones 
            WHERE NOT (fecha SIMILAR TO '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]');
        """)
        fechas_problematicas = cursor.fetchone()[0]
        print(f"   Fechas problemáticas encontradas: {fechas_problematicas}")
        
        # PASO 3: Mostrar ejemplos de fechas problemáticas
        if fechas_problematicas > 0:
            cursor.execute("""
                SELECT id_registro, fecha 
                FROM operaciones 
                WHERE NOT (fecha SIMILAR TO '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')
                LIMIT 10;
            """)
            
            print("\\n?? Ejemplos de fechas problemáticas:")
            for row in cursor.fetchall():
                print(f"   ID: {row[0]}, Fecha: '{row[1]}'")
        
        # PASO 4: Correcciones específicas
        print("\\n?? Aplicando correcciones...")
        
        correcciones = 0
        
        # Corrección 1: Fechas con mes sin cero (2024-8-21 ? 2024-08-21)
        cursor.execute("""
            UPDATE operaciones 
            SET fecha = SUBSTR(fecha, 1, 5) || '0' || SUBSTR(fecha, 6)
            WHERE LENGTH(fecha) = 9 AND SUBSTR(fecha, 6, 1) != '0' AND SUBSTR(fecha, 5, 1) = '-' AND SUBSTR(fecha, 7, 1) = '-';
        """)
        corr1 = cursor.rowcount
        correcciones += corr1
        print(f"   ? Corrección mes sin cero: {corr1} registros")
        
        # Corrección 2: Fechas con día sin cero (2024-08-1 ? 2024-08-01)
        cursor.execute("""
            UPDATE operaciones 
            SET fecha = SUBSTR(fecha, 1, 8) || '0' || SUBSTR(fecha, 9)
            WHERE LENGTH(fecha) = 9 AND SUBSTR(fecha, 9, 1) != '0' AND SUBSTR(fecha, 8, 1) = '-';
        """)
        corr2 = cursor.rowcount
        correcciones += corr2
        print(f"   ? Corrección día sin cero: {corr2} registros")
        
        # Corrección 3: Fechas formato DD-MM-YYYY cuando día > 12
        cursor.execute("""
            SELECT id_registro, fecha 
            FROM operaciones 
            WHERE fecha SIMILAR TO '[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]'
            AND SUBSTR(fecha, 1, 2)::INTEGER > 12
            LIMIT 5;
        """)
        
        fechas_europeas = cursor.fetchall()
        if fechas_europeas:
            print(f"   ?? Fechas formato europeo encontradas: {len(fechas_europeas)}")
            for row in fechas_europeas:
                parts = row[1].split('-')
                if len(parts) == 3:
                    nueva_fecha = f"{parts[2]}-{parts[1]}-{parts[0]}"
                    cursor.execute("""
                        UPDATE operaciones 
                        SET fecha = %s 
                        WHERE id_registro = %s;
                    """, (nueva_fecha, row[0]))
                    correcciones += 1
        
        conn.commit()
        
        # PASO 5: Verificaciones finales
        print("\\n?? VERIFICACIONES FINALES:")
        
        cursor.execute("SELECT COUNT(*) FROM operaciones;")
        total = cursor.fetchone()[0]
        
        cursor.execute("""
            SELECT COUNT(*) FROM operaciones 
            WHERE fecha SIMILAR TO '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]';
        """)
        fechas_validas = cursor.fetchone()[0]
        
        cursor.execute("""
            SELECT COUNT(*) FROM operaciones 
            WHERE NOT (fecha SIMILAR TO '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]');
        """)
        fechas_invalidas = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM operaciones WHERE id_region IS NOT NULL;")
        con_region = cursor.fetchone()[0]
        
        print(f"   Total operaciones: {total:,}")
        print(f"   Fechas válidas: {fechas_validas:,} ({(fechas_validas/total)*100:.2f}%)")
        print(f"   Fechas inválidas: {fechas_invalidas:,} ({(fechas_invalidas/total)*100:.2f}%)")
        print(f"   Con id_region: {con_region:,} ({(con_region/total)*100:.2f}%)")
        print(f"   Total correcciones aplicadas: {correcciones}")
        
        # Crear tabla de operaciones corregidas
        cursor.execute("DROP TABLE IF EXISTS operaciones_corregida;")
        cursor.execute("CREATE TABLE operaciones_corregida AS SELECT * FROM operaciones;")
        conn.commit()
        
        print("\\n? Tabla operaciones_corregida creada")
        
        # Mostrar algunas fechas restantes problemáticas
        if fechas_invalidas > 0:
            cursor.execute("""
                SELECT id_registro, fecha 
                FROM operaciones 
                WHERE NOT (fecha SIMILAR TO '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]')
                LIMIT 5;
            """)
            
            print("\\n?? Fechas que requieren revisión manual:")
            for row in cursor.fetchall():
                print(f"   ID: {row[0]}, Fecha: '{row[1]}'")
        
        conn.close()
        print("\\n?? DATA CLEANSING COMPLETADO")
        
    except Exception as e:
        print(f"? Error: {e}")

if __name__ == "__main__":
    data_cleansing_simplificado()