import sys
import psycopg2
from psycopg2 import Error
import csv


# Variables globales

error_con = False
id_pais   = 57


# Parámetros de conexión de la Base de datos local

v_host	   = "localhost"
v_database = "bigdata"
v_port     = "5432"
v_user     = "postgres"
v_password = "postgres"


# Función: Obtener Código de Región

def getCodigoRegion(region):
    codigo_region = 0
    if region == "Region Eje Cafetero - Antioquia":
        codigo_region = 1
    elif region == "Region Centro Oriente":
        codigo_region = 2
    elif region == "Region Centro Sur":
        codigo_region = 3
    elif region == "Region Caribe":
        codigo_region = 4
    elif region == "Region Llano":
        codigo_region = 5
    elif region == "Region Pacifico":
        codigo_region = 6
    else:
        codigo_region = 0
    return codigo_region    


# Función: Carga Tabla Temporal

def cargarTablaTemporal(conn, cursor, contador, 
                        nombre_region, codigo_region, 
                        codigo_dep, departamento, 
                        codigo_mun, municipio):
    
    print("Cargando temporal ... -> ", len(codigo_mun) , contador, 
        codigo_dep, codigo_mun, codigo_region, 
        departamento, municipio, nombre_region)

    if (len(codigo_mun) > 10):
        print("Problemas con el código de departamento ... fila -> ",contador+1)
        return
    try:
        comando_sql = '''INSERT INTO temporal(codigo_region, codigo_dep, codigo_mun, departamento, municipio, region) 
                    VALUES (%s,%s,%s,%s,%s,%s);'''
        cursor.execute(comando_sql, 
                    (codigo_region, codigo_dep, codigo_mun, departamento, municipio, nombre_region))
        conn.commit()
    except (Exception, Error) as error:
        print("Error: ", error)
        sys.exit("Error: Carga tabla temporal!")
    finally:
        return


# Función: Cargar Departamentos

def cargarDepartamento(conn, cursor, 
                    codigo_departamento, nombre_departamento, 
                    codigo_region,
                    cantidad):
    id_pais         = 57
    sufijo          = str(codigo_departamento).zfill(2)
    id_departamento = int(str(id_pais) + sufijo)    
    nombre_dep      = nombre_departamento[0:50]
    print(sufijo, id_departamento, nombre_dep, codigo_departamento, codigo_region, cantidad)
    
    comando_sql = '''INSERT INTO departamentos (id_departamento, codigo_dane, nombre, codigo_region) 
                VALUES (%s,%s,%s,%s);'''
    cursor.execute(comando_sql, 
                (id_departamento, codigo_departamento, nombre_dep, codigo_region))
    conn.commit()
    return


# Función: Cargar Municipios

def cargarMunicipio(conn, cursor, contador, codigo_dep, codigo_mun, municipio):
    try:
        sufijo          = str(codigo_dep).zfill(2)
        id_departamento = int(str(57) + sufijo)    
        sufijo          = str(contador).zfill(3)
        id_municipio    = int(str(id_departamento) + sufijo)
        municipio       = municipio[0:50]
        print(contador, codigo_dep, codigo_mun, id_departamento, id_municipio, municipio)
        
        comando_sql = '''INSERT INTO municipios (id_departamento, id_municipio, codigo_dane, nombre) 
                    VALUES (%s,%s,%s,%s);'''
        cursor.execute(comando_sql, 
                    (id_departamento, id_municipio, codigo_mun, municipio))
        conn.commit()
    except (Exception, Error) as error:
        print("Error: ", error)
        sys.exit("Error: Carga tabla municipios!")
    finally:
        return


# NUEVA FUNCIÓN: Actualizar id_region en tabla operaciones

def actualizarIdRegionOperaciones(conn, cursor):
    try:
        print("=== INICIANDO ACTUALIZACIÓN DE ID_REGION EN OPERACIONES ===")
        
        # Verificar si el campo id_region existe
        cursor.execute("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'operaciones' AND column_name = 'id_region';
        """)
        
        if not cursor.fetchone():
            print(" Campo id_region no existe. Agregando...")
            cursor.execute("ALTER TABLE operaciones ADD COLUMN id_region INTEGER;")
            conn.commit()
            print(" Campo id_region agregado")
        
        # Actualizar id_region en operaciones basado en departamentos
        comando_sql = '''
            UPDATE operaciones 
            SET id_region = d.codigo_region
            FROM departamentos d 
            WHERE operaciones.id_departamento = d.id_departamento
            AND (operaciones.id_region IS NULL OR operaciones.id_region = 0);
        '''
        
        cursor.execute(comando_sql)
        filas_actualizadas = cursor.rowcount
        conn.commit()
        
        print(f" {filas_actualizadas} operaciones actualizadas con id_region")
        
        # Verificar resultados
        cursor.execute("SELECT COUNT(*) FROM operaciones WHERE id_region IS NOT NULL AND id_region > 0;")
        ops_con_region = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM operaciones;")
        total_ops = cursor.fetchone()[0]
        
        print(f" Operaciones con id_region: {ops_con_region} de {total_ops}")
        
        # Verificar si existe tabla regiones
        cursor.execute("""
            SELECT table_name FROM information_schema.tables 
            WHERE table_name = 'regiones';
        """)
        
        if cursor.fetchone():
            # Mostrar distribución por región
            cursor.execute('''
                SELECT r.nombre_region, COUNT(o.id_registro) as operaciones
                FROM regiones r
                LEFT JOIN operaciones o ON r.id_region = o.id_region
                GROUP BY r.id_region, r.nombre_region
                ORDER BY operaciones DESC;
            ''')
            
            print(" DISTRIBUCIÓN POR REGIÓN:")
            for row in cursor.fetchall():
                print(f"   {row[0]}: {row[1]:,} operaciones")
        else:
            print("?? Tabla regiones no existe. Distribución por código:")
            cursor.execute('''
                SELECT id_region, COUNT(*) as operaciones
                FROM operaciones 
                WHERE id_region IS NOT NULL
                GROUP BY id_region
                ORDER BY operaciones DESC;
            ''')
            
            for row in cursor.fetchall():
                print(f"   Región {row[0]}: {row[1]:,} operaciones")
            
        print("=== ACTUALIZACIÓN DE ID_REGION COMPLETADA ===")
        
    except (Exception, Error) as error:
        print(f" Error actualizando id_region: {error}")
        conn.rollback()
        raise error


# PROGRAMA PRINCIPAL - PROCESO ETL

try:
    print("=== INICIANDO PROCESO ETL CON ACTUALIZACIÓN DE ID_REGION ===")
    
    # Conexión a la base de datos
    connection = psycopg2.connect(user=v_user, password=v_password, 
                                host=v_host, port=v_port, database=v_database)
    cursor = connection.cursor()
    
    # PASO 1: Limpiar tablas
    print("\\nPASO 1: Limpiando tablas...")
    cursor.execute("TRUNCATE temporal;")
    cursor.execute("TRUNCATE departamentos CASCADE;")  
    cursor.execute("TRUNCATE municipios CASCADE;")
    connection.commit()
    print(" Tablas limpiadas")

    # PASO 2: Cargar datos desde CSV
    print("\\nPASO 2: Cargando datos desde CSV...")
    with open('colombia-dane-departamentos.csv', 'r', encoding='utf-8', errors='ignore') as archivo_csv:
        lector_csv = csv.reader(archivo_csv, delimiter=',', quotechar='"')
        contador = 0
        for fila in lector_csv:
            contador += 1
            if contador == 1:  # Saltar cabecera
                continue
                
            if len(fila) != 5:
                print(f"?? Fila {contador} tiene {len(fila)} columnas, se esperaban 5. Saltando...")
                continue
                
            nombre_region = fila[0]
            codigo_dep = fila[1]
            departamento = fila[2]
            codigo_mun = fila[3]
            municipio = fila[4]
            
            codigo_region = getCodigoRegion(nombre_region)
            cargarTablaTemporal(connection, cursor, contador, nombre_region, 
                            codigo_region, codigo_dep, departamento, codigo_mun, municipio)
    
    print(f" {contador-1} registros cargados en tabla temporal")

    # PASO 3: Cargar Departamentos desde tabla temporal
    print("\\nPASO 3: Cargando departamentos...")
    cursor.execute('''
        SELECT codigo_dep, departamento, codigo_region, count(*) 
        FROM temporal 
        GROUP BY codigo_dep, departamento, codigo_region 
        ORDER BY departamento;
    ''')
    
    tuplas_departamentos = cursor.fetchall()
    for tupla in tuplas_departamentos:
        cargarDepartamento(connection, cursor, tupla[0], tupla[1], tupla[2], tupla[3])
    
    print(f" {len(tuplas_departamentos)} departamentos cargados")

    # PASO 4: Cargar Municipios desde tabla temporal
    print("\\nPASO 4: Cargando municipios...")
    cursor.execute('''
        SELECT codigo_dep, codigo_mun, municipio 
        FROM temporal 
        ORDER BY departamento, municipio;
    ''')
    
    tuplas_municipios = cursor.fetchall()
    contador = 0
    codigo_old = ''
    
    for tupla in tuplas_municipios:
        codigo_dep = tupla[0]
        codigo_mun = tupla[1]
        municipio = tupla[2]
        
        if codigo_dep == codigo_old:
            contador += 1
        else:
            contador = 1
        codigo_old = codigo_dep
        
        cargarMunicipio(connection, cursor, contador, codigo_dep, codigo_mun, municipio)
    
    print(f" {len(tuplas_municipios)} municipios cargados")

    # PASO 5: NUEVO - Actualizar id_region en operaciones
    print("\\nPASO 5: Actualizando id_region en operaciones...")
    actualizarIdRegionOperaciones(connection, cursor)
    
    # Finalizar
    connection.commit()
    connection.close()
    
    print("\\n PROCESO ETL COMPLETADO EXITOSAMENTE CON ID_REGION")
    
except (Exception, Error) as error:
    print(f" Error de procesamiento: {error}")
finally:
    if connection:
        connection.close()
        print("?? Conexión PostgreSQL cerrada")

print("\\n=== FIN DEL PROCESO ETL CON ID_REGION ===")