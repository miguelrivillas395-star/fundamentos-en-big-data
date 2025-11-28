# Big Data ETL - Taller Continuidad
## Sistema de Gestión de Ventas de Gaseosas

**Curso:** ET-0155 - Fundamentos de Big Data - I.U. Pascual Bravo  
**Profesor:** MSc Jaime Ernesto Soto U


##  **ESTRUCTURA DEL PROYECTO**

```
 bigdata-etl-project/
├──  algoritmo-etl-con-id-region.py     # ETL principal
├──  data-cleansing-simple.py           # Limpieza de datos
├──  diccionario-datos.md               # Diccionario completo
├──  scripts-sql/                       # Scripts SQL
├──  colombia-dane-departamentos.csv    # Datos DANE
└──  README.md                          # Este archivo
```

---

##  **INICIO RÁPIDO**

### **1. Clonar Repositorio:**
```bash
git clone [URL_REPOSITORIO]
cd bigdata-etl-project
```

### **2. Activar Entorno Python:**
```bash
.venv\Scripts\activate  # Windows
pip install psycopg2-binary pandas
```

### **3. Configurar PostgreSQL:**
- **Base de Datos:** `bigdata`
- **Usuario:** `postgres` 
- **Contraseña:** `postgres`
- **Puerto:** `5432`

### **4. Ejecutar Scripts SQL:**
```bash
# En pgAdmin o psql, ejecutar en orden:
scripts-sql/script-base-datos-creacion.sql
scripts-sql/script-base-datos-operaciones.sql
scripts-sql/script-base-datos-vista.sql
scripts-sql/script-agregar-id-region.sql
```

### **5. Ejecutar ETL:**
```bash
python algoritmo-etl-con-id-region.py
python data-cleansing-simple.py
```
