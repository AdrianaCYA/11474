USE DB_CALCULATOR
GO

-- Creamos una nueva tabla para guardar los valores actuales de parametros
	IF EXISTS (SELECT 1 FROM SYS.OBJECTS WHERE NAME='CAL_ParamsOld')
		DROP TABLE CAL_ParamsOld
	GO
	Create table CAL_ParamsOld(
	  idParam INT NOT NULL PRIMARY KEY IDENTITY(1,1),
	  paramCode NVARCHAR(20) NOT NULL,
	  paramName NVARCHAR(100),
	  paramValue NVARCHAR(8) NOT NULL,
	  season NVARCHAR(100) NOT NULL,
	  enabled BIT DEFAULT(1),
	  paramGroup INT DEFAULT(1)
	);

-- Guardamos los valores de los parametros en la nueva tabla
	INSERT INTO CAL_ParamsOld (paramCode, paramName, paramValue, season, enabled, paramGroup)
	SELECT paramCode, paramName, paramValue, season, enabled, paramGroup FROM CAL_Params

-- Comprobamos que las tablas tengan la misma informacion	
	IF(SELECT COUNT(*) FROM CAL_ParamsOld) <> (SELECT COUNT(*) FROM CAL_Params)
	BEGIN
		PRINT 'LAS CANTIDADES DE CAL_ParamsOld y CAL_Params SON DIFERENTES'
		RETURN
	END

-- Agregamos la nueva columna de division a la tabla de parametros		
	ALTER TABLE CAL_Params ADD division NVARCHAR(50) 

	-- Borramos los datos actuales de la tabla CAL_Params
	DELETE FROM CAL_Params
-- Guardamos los parametros por division en la tabla CAL_Params
	DECLARE @division NVARCHAR(50)
	DECLARE @season NVARCHAR(50)
	-- Declaramos el cursor	
	DECLARE CPARAMSDIVISION CURSOR FOR
		SELECT DISTINCT(division) FROM CAL_VIEW_CommercialStructure
	OPEN CPARAMSDIVISION
		FETCH NEXT FROM CPARAMSDIVISION INTO @division
		WHILE @@FETCH_STATUS = 0
		BEGIN
			DECLARE CPARAMSSEASON CURSOR FOR
				SELECT DISTINCT(season) FROM CAL_ParamsOld
			OPEN CPARAMSSEASON
				FETCH NEXT FROM CPARAMSSEASON INTO @season
				WHILE @@FETCH_STATUS = 0
				BEGIN 
					INSERT INTO CAL_Params (paramCode, paramName, paramValue, season, enabled, paramGroup, division)
					SELECT paramCode, paramName, paramValue, season, enabled, paramGroup, @division FROM CAL_ParamsOld WHERE season = @season
					FETCH NEXT FROM CPARAMSSEASON INTO @season
				END
			CLOSE CPARAMSSEASON
			DEALLOCATE CPARAMSSEASON
			FETCH NEXT FROM CPARAMSDIVISION INTO @division
		END
	CLOSE CPARAMSDIVISION
	DEALLOCATE CPARAMSDIVISION

-- Comprobamos que las cantidad de información sea correcta	
	IF((SELECT COUNT(*) FROM CAL_ParamsOld)*(SELECT COUNT(DISTINCT(division)) FROM CAL_VIEW_CommercialStructure)) <> (SELECT COUNT(*) FROM CAL_Params)
	BEGIN
		PRINT 'LAS CANTIDADES DE CAL_ParamsOld * CANTIDAD DE DIVISIONES y LA CANTIDAD TOTAL DE CAL_Params SON DIFERENTES'
		RETURN
	END

	PRINT 'EJECUTADO CON EXITO'