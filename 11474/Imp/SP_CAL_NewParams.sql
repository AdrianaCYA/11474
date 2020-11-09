Use DB_CALCULATOR
GO

IF EXISTS (SELECT 1 FROM SYS.OBJECTS WHERE NAME='SP_CAL_NewParams')
	DROP PROCEDURE SP_CAL_NewParams
GO
CREATE PROCEDURE SP_CAL_NewParams(
	@Result NVARCHAR(50) OUTPUT,
	@season NVARCHAR(100),
	@division NVARCHAR(50)
)
AS
BEGIN
	INSERT INTO CAL_Params(paramCode, paramName, paramValue, season, division, paramGroup) VALUES
		('NumTiendas', 'Numero de tiendas', '0', @season, @division, 1),
		('PorPackBvsPackA', 'Porcentaje Pack B vs Pack A', '0', @season, @division, 1),
		('MinPzSku', 'Minimo de piezas por SKU', '0', @season, @division, 1),
		('PorCompraSku', 'Porcentaje compra SKU', '0',@season, @division, 1),
		('PzPackSimple', 'Piezas de pack simple', '0', @season, @division, 1),
		('PzSplit', 'Piezas por split', '0', @season, @division, 1),
		('PorPedNac1', 'Porcentaje del 1 pedido nacional', '100', @season, @division, 2),
		('PorPedNac2', 'Porcentaje del 2 pedido nacional', '0', @season, @division, 2),
		('PorPedNac3', 'Porcentaje del 3 pedido nacional', '0', @season, @division, 2),
		('PorPedNac4', 'Porcentaje del 4 pedido nacional', '0', @season, @division, 2),
		('PorPedNac5', 'Porcentaje del 5 pedido nacional', '0', @season, @division, 2),
		('PorPedNac6', 'Porcentaje del 6 pedido nacional', '0', @season, @division, 2),
		('PorPedNac7', 'Porcentaje del 7 pedido nacional', '0', @season, @division, 2),
		('PorPedNac8', 'Porcentaje del 8 pedido nacional', '0', @season, @division, 2),
		('PorPedNac9', 'Porcentaje del 9 pedido nacional', '0', @season, @division, 2),
		('PorPedNac10', 'Porcentaje del 10 pedido nacional', '0', @season, @division, 2),
		('PorPedImp1', 'Porcentaje del 1 pedido importado', '100', @season, @division, 3),
		('PorPedImp2', 'Porcentaje del 2 pedido importado', '0', @season, @division, 3),
		('PorPedImp3', 'Porcentaje del 3 pedido importado', '0', @season, @division, 3),
		('PorPedImp4', 'Porcentaje del 4 pedido importado', '0', @season, @division, 3),
		('PorPedImp5', 'Porcentaje del 5 pedido importado', '0', @season, @division, 3),
		('PorPedImp6', 'Porcentaje del 6 pedido importado', '0', @season, @division, 3),
		('PorPedImp7', 'Porcentaje del 7 pedido importado', '0', @season, @division, 3),
		('PorPedImp8', 'Porcentaje del 8 pedido importado', '0', @season, @division, 3),
		('PorPedImp9', 'Porcentaje del 9 pedido importado', '0', @season, @division, 3),
		('PorPedImp10', 'Porcentaje del 10 pedido importado', '0', @season, @division, 3);
	RETURN
END
