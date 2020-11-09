USE DB_CALCULATOR
GO

-- Eliminar tabala params
	IF EXISTS (SELECT 1 FROM SYS.OBJECTS WHERE NAME='CAL_Params')
		DROP TABLE CAL_Params
	GO
-- Renombramos la tabla de respaldo de parametros como la actual
	EXEC sp_rename 'CAL_ParamsOld', 'CAL_Params'