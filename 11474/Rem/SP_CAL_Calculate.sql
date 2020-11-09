Use DB_CALCULATOR
GO

IF EXISTS (SELECT 1 FROM SYS.OBJECTS WHERE NAME='SP_CAL_Calculate')
	DROP PROCEDURE SP_CAL_Calculate
GO
CREATE PROCEDURE SP_CAL_Calculate(
	@Result NVARCHAR(100) OUTPUT,
	@DevStyleColor INT = -1
)
AS
BEGIN
    BEGIN TRY
        --Declaracion de variable
        DECLARE @DevStyle INT
        DECLARE @division NVARCHAR(50)
        DECLARE @subDivision NVARCHAR(50)
        DECLARE @comercialGroup NVARCHAR(50)
        DECLARE @family NVARCHAR(50)
        DECLARE @subFamily NVARCHAR(50)
        DECLARE @seasonOld NVARCHAR(50)
        DECLARE @season NVARCHAR(50)
        DECLARE @typeSize NVARCHAR(30)
        DECLARE @forecast int
        DECLARE @minPzSKU int
        DECLARE @numTiendas int
        DECLARE @piezasPackA NUMERIC (13,6)
        DECLARE @porCompraSKU DECIMAL(13,6)
        DECLARE @porPackBvsPackA DECIMAL(13,6)
        DECLARE @pzPackSimple int
        DECLARE @numMinTallas int
        DECLARE @minimoTiendas int
        DECLARE @codigoDistribucion int
		DECLARE @ResultType INT
		DECLARE @PzSplit INT
        --Comparamos si se ingreso un numero de pedido
        IF @DevStyleColor < 0
        BEGIN
            SET @Result = 'ERROR: Falta el ID a buscar'
            RETURN
        END

    /* Inicializacion de las variables globales */
        -- Variable resultado final
        SET @Result = ''
        -- Estructura comercial
        SELECT	@division = division, @subDivision = subDivision, @comercialGroup = comercialGroup,
                @family = family, @subFamily = subFamily, @typeSize = typeSize, @forecast = forecast,
                @seasonOld = CONCAT(season,(CONCAT(' 20',yearOrder-1))), --NOTA: EN EL 2100 cambiar a 21
                @season = CONCAT(season,(CONCAT(' 20',yearOrder))),
                @DevStyle = ID_DevelopmentStyle
            FROM CAL_VIEW_Orders WHERE ID_DevelopmentStyleColor = @DevStyleColor

        IF @season IS NULL
        BEGIN
            SET @Result = 'CAL: Faltan datos en el estilo para ejecutar la calculadora '
            INSERT INTO CAL_LogCalculate (dateExecution, model, descriptionLog)
            VALUES (GETDATE(), @DevStyleColor, 'Faltan datos en el estilo para ejecutar la calculadora')
            RETURN
        END

		EXEC SP_CAL_GetTypeSize @Result = @ResultType OUTPUT, @TypeSize = @TypeSize OUTPUT,	@Style = @DevStyle
		SELECT @ResultType, @typeSize
		IF @ResultType = 0
		BEGIN
			SET @Result = @typeSize
			INSERT INTO CAL_LogCalculate (dateExecution, model, descriptionLog)
			VALUES (GETDATE(), @DevStyleColor, @typeSize)
			RETURN
		END

        -- Minimo de piezas por SKU
        SELECT	@minPzSKU = paramValue FROM CAL_Params WHERE paramCode = 'MinPzSku' and season = @season
        -- Numero de Tiendas
        SELECT	@numTiendas = paramValue FROM CAL_Params WHERE paramCode = 'NumTiendas' and season = @season
        -- Porcentaje de compra por SKU
        SELECT	@porCompraSKU = paramValue FROM CAL_Params WHERE paramCode = 'PorCompraSku' and season = @season
        SET @porCompraSKU = @porCompraSKU / 100
        -- Porcentaje de Pack B contra Pack A
        SELECT	@porPackBvsPackA = paramValue FROM CAL_Params WHERE paramCode = 'PorPackBvsPackA' and season = @season
        SET @porPackBvsPackA = @porPackBvsPackA / 100
        -- Piezas por pack simple
        SELECT	@pzPackSimple = paramValue FROM CAL_Params WHERE paramCode = 'PzPackSimple' and season = @season
        -- Piezas por Pack A
        SELECT	@piezasPackA = quantity FROM CAL_PackAQuantity WHERE @division = division AND @subDivision = subDivision AND
                @comercialGroup = comercialGroup AND @family = family AND @subFamily = subFamily AND @typeSize = typeSize
         -- Codigo de distribucion (tropicalizacion)
        SET @codigoDistribucion = (SELECT TOP 1 code FROM CAL_VIEW_Orders WHERE ID_DevelopmentStyleColor = @DevStyleColor)
        -- Minimo numero de tiendas
        SELECT	@minimoTiendas = CASE WHEN @codigoDistribucion = 0 OR @codigoDistribucion = '' THEN @numTiendas ELSE @codigoDistribucion END
		-- Piezas por split
		SELECT @PzSplit = paramValue FROM CAL_Params WHERE paramCode = 'PzSplit' AND season = @season
	/* FIN Inicializacion de las variables globales */

		IF	@minPzSKU IS NULL OR @numTiendas IS NULL OR @porCompraSKU IS NULL OR @porCompraSKU = 0 OR @porPackBvsPackA IS NULL OR
			@porPackBvsPackA = 0 OR @pzPackSimple IS NULL OR @PzSplit IS NULL
        BEGIN
            SET @Result = CONCAT('CAL: Faltan parametros de la temporada ', @season)
            INSERT INTO CAL_LogCalculate (dateExecution, model, descriptionLog)
            VALUES (GETDATE(), @DevStyleColor, CONCAT('Error Calculadora: Faltan parametros de la temporada ', @season))
            RETURN
        END
        -- Mostramos los datos globales a usar
        SELECT @DevStyleColor as ID, @division AS division, @subDivision AS subDivision, @comercialGroup AS comercialGroup, @family AS family,
        @subFamily AS subFamily, @seasonOld, @season
        --Comparamos si existe Piezas de Pack A
        IF @piezasPackA IS NULL
		BEGIN
			SET @Result = CONCAT('CAL: No existen tamaño de Pack A para el tipo de talla ', @typeSize)
			INSERT INTO CAL_LogCalculate (dateExecution, model, descriptionLog)
			VALUES (GETDATE(), @DevStyleColor, CONCAT('Error Calculadora: No existen tamaño de Pack A para el tipo de talla ',@typeSize))
			RETURN
		END

    /* Declaracion de tablas temporales a usar */
		-- Tabla temporal PackA
		IF OBJECT_ID('tempdb.dbo.#PackA', 'U') IS NOT NULL
			DROP TABLE #PackA;
		CREATE TABLE #PackA (ID INT IDENTITY (1,1), size NVARCHAR(50), division NVARCHAR(50),  subDivision NVARCHAR(50),
			comercialGroup NVARCHAR(50),  family NVARCHAR(50),  subFamily NVARCHAR(50), season NVARCHAR(100),
			typeSize NVARCHAR(30),
			share DECIMAL(13,6), shareMin bit, sharePackA DECIMAL(13,6), sharePzPack DECIMAL(13,6),
			packAR int, valida1 int, beneficio DECIMAL(13,6), packA int, valida2 int
		)
		-- Tabla Temporal para obtener el Calculos
		IF OBJECT_ID('tempdb.dbo.#Calculos', 'U') IS NOT NULL
			DROP TABLE #Calculos;
		CREATE TABLE #Calculos (ID INT IDENTITY (1,1), sku NVARCHAR(50), division NVARCHAR(50),  subDivision NVARCHAR(50),
			comercialGroup NVARCHAR(50),  family NVARCHAR(50),  subFamily NVARCHAR(50), size NVARCHAR(50), id_StyleSku INT,
			typeSize NVARCHAR(30), season NVARCHAR(100), share DECIMAL(13,6), sharePackA DECIMAL(13,6), packA int, numPackA INT, compraPackA INT,
			compraIdeal INT, tallasPackB DECIMAL(13,6),	share1PackB DECIMAL(13,6), share2PackB DECIMAL(13,6), sharePackB DECIMAL(13,6),
			packB int, numPackB INT, compraPackB INT, skuVal INT, packSimple INT,  compraReal INT, forecastSharePackA INT, shareSKU INT,
			PzXPackA INT, PzXPackB INT, PzXSKU INT, CompraRealSplit INT
		)
	/* FIN Declaracion de tablas temporales a usar */

        -- Insertamos en tabla temporal los datos a calcular por modelo
		INSERT INTO #Calculos
			SELECT distinct(p.sku), v.division, v.subDivision, v.comercialGroup, v.family, v.subFamily, p.size, p.ID_DevelopmentStyleValidSKU, v.typeSize,
				@season, share, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
			FROM CAL_Sales AS v
			JOIN CAL_VIEW_Orders AS p ON v.division = p.division  AND v.subDivision = p.subDivision  AND
											v.comercialGroup = p.comercialGroup  AND v.family = p.family  AND
											v.subFamily = p.subFamily  AND-- v.typeSize = p.typeSize  AND
											v.size = p.size
			WHERE v.division = @division AND v.subDivision = @subDivision AND v.comercialGroup = @comercialGroup AND v.family = @family
				AND v.subFamily = @subFamily AND v.season = @seasonOld AND v.typeSize = @typeSize AND p.ID_DevelopmentStyleColor = @DevStyleColor
			ORDER BY size ASC

		--Comparamos si existe historico
		IF (SELECT COUNT(*) FROM #Calculos) <= 0
		BEGIN
			SET @Result = CONCAT('CAL: No existe historico para el tipo de talla ', @typeSize)
			INSERT INTO CAL_LogCalculate (dateExecution, model, descriptionLog)
				VALUES (GETDATE(), @DevStyleColor, CONCAT('Error Calculadora:No existe historico para el tipo de talla ',@typeSize))
			RETURN
		END

   /* InicializaciOn de las variables globales */
		-- Numero minimo de tallas
		SELECT	@numMinTallas = minPackB FROM CAL_RemoveSize WHERE numSizePackA = (SELECT COUNT(share) FROM #Calculos WHERE share > 0)
	/* FIN InicializaciOn de las variables globales */

	-- Mostramos los datos globales a usar
		SELECT @DevStyleColor as ID, @division AS division, @subDivision AS subDivision, @comercialGroup AS comercialGroup, @family AS family,
		@subFamily AS subFamily, @typeSize AS typeSize, @forecast AS forecast, @season AS season, @minPzSKU AS minPzSKU, @numTiendas AS numTiendas,
		@piezasPackA AS pzPackA, @porCompraSKU AS porCompraSKU, @porPackBvsPackA AS porPackBvsPackA, @numMinTallas AS numMinTallas,
		@PzSplit as piezasPorSplit

	/* Veficacion 100% de share */
        UPDATE #Calculos
        SET share = (share/ (SELECT SUM(share) FROM #Calculos))
    /* FIN Verificacion 100% de share*/
    /* Calculo de Pack A */
        -- CALCULAMOS EL SHARE MIN
        INSERT INTO #PackA
            SELECT v.division, v.subDivision, v.comercialGroup, v.family, v.subFamily,  @season,v.typeSize, p.size, share,
            --CASE WHEN share > 1/@piezasPackA THEN 'true' ELSE 'false' END AS shareMin,
            0, 0, 0, 0, 0, 0, 0, 0
            FROM CAL_Sales AS v
            JOIN CAL_VIEW_Orders AS p ON v.division = p.division  AND v.subDivision = p.subDivision  AND
                                            v.comercialGroup = p.comercialGroup  AND v.family = p.family  AND
                                            v.subFamily = p.subFamily  AND --v.typeSize = p.typeSize  AND
                                            v.size = p.size
                WHERE v.division = @division AND v.subDivision = @subDivision AND v.comercialGroup = @comercialGroup AND v.family = @family
                    AND v.subFamily = @subFamily AND v.season = @seasonOld AND v.typeSize = @typeSize AND p.ID_DevelopmentStyleColor = @DevStyleColor
                ORDER BY size ASC

        /* Veficacion 100% de share */
            UPDATE #PackA
            SET share = (share/ (SELECT SUM(share) FROM #PackA))

            UPDATE #PackA
            SET shareMin = CASE WHEN share > 1/@piezasPackA THEN 'true' ELSE 'false' END
        /* FIN Verificacion 100% de share*/
        -- Calculamos el Share Pack A
        UPDATE #PackA
            SET sharePackA = t.data
            FROM #PackA AS p, (
                SELECT
                ID,
                CASE WHEN shareMin = 'false'
                    THEN (1/@piezasPackA)*100
                    ELSE (((1-((SELECT COUNT(*) FROM #PackA WHERE shareMin = 'false') * ( 1 / @piezasPackA))) * share)
                            / ((SELECT SUm(share) FROM #PackA WHERE shareMin = 'true') /100))
                END AS data
                FROM #PackA AS temp
            ) AS t
            WHERE p.ID = t.ID
        -- Guardamos Pack A en la tabla #Calculos
            UPDATE #Calculos
            SET sharePackA = t.sharePackA
            FROM #Calculos AS v, (
                    SELECT sharePackA, ID FROM #PackA
            ) AS t
            WHERE t.ID = v.ID
        -- Calculamos Share Piezas por Pack
        UPDATE #PackA
            SET sharePzPack = t.data
            FROM #PackA as p, (
                SELECT
                    ID,
                    CASE WHEN sharePackA < (1/@piezasPackA)
                        THEN 1
                        ELSE (@piezasPackA*(sharePackA)/100)
                    END AS data
                FROM #PackA
            ) AS t
            WHERE p.ID = t.ID
        -- Calculamos Pack A R
        UPDATE #PackA
            SET packAR = t.data
            FROM #PackA as p, (
                SELECT
                    ID,
                    CASE WHEN (share) < (1/@piezasPackA)
                        THEN 1
                        ELSE ROUND(@piezasPackA*(sharePackA)/100,0)
                    END AS data
                    FROM #PackA
            ) AS t
            WHERE p.ID = t.ID
        -- Calculamos Valida1
        UPDATE #PackA
            SET valida1 = (SELECT SUM(packAR) FROM #PackA)
        -- Calculamos Beneficio
        UPDATE #PackA
            SET beneficio = t.data
            FROM (
                SELECT
                ID as ide,
                CASE WHEN valida1 = @piezasPackA
                    THEN 0
                    ELSE (packAR - sharePzPack)
                END AS data
                FROM #PackA
            )AS t
            WHERE ID = t.ide
        -- Calculamos PackA
        UPDATE #PackA
            SET packA = t.data
            FROM #PackA as p, (
                SELECT ID as ide,
                CASE
                WHEN valida1 > @piezasPackA
                    THEN (
                        CASE
                        WHEN
                            valida1 - @piezasPackA = 1 AND
                            (SELECT TOP(1) tr.rankBen FROM (
                                SELECT RANK() OVER( ORDER BY beneficio DESC) AS rankBen, beneficio FROM #PackA AS r
                            ) AS tr where tr.beneficio = temp.beneficio ) = 1
                            THEN packAR - 1
                            WHEN
                                @piezasPackA - valida1 = 2 AND
                                (SELECT TOP(1) tr.rankBen FROM (
                                    SELECT RANK() OVER( ORDER BY beneficio DESC) AS rankBen, beneficio FROM #PackA AS r
                                ) AS tr where tr.beneficio = temp.beneficio ) = 1
                                THEN packAR - 1
                            WHEN
                                @piezasPackA - valida1 = 2 AND
                                (SELECT TOP(1) tr.rankBen FROM (
                                    SELECT RANK() OVER( ORDER BY beneficio DESC) AS rankBen, beneficio FROM #PackA AS r
                                ) AS tr where tr.beneficio = temp.beneficio ) = 2
                                THEN packAR - 1
                            ELSE packAR
                            END
                    )
                    WHEN valida1 < @piezasPackA
                    THEN (
                        CASE
                        WHEN
                            @piezasPackA - valida1 = 1 AND
                            (SELECT TOP(1) tr.rankBen FROM (
                                SELECT RANK() OVER( ORDER BY beneficio ASC) AS rankBen, beneficio FROM #PackA AS r
                            ) AS tr where tr.beneficio = temp.beneficio ) = 1
                            THEN packAR + 1
                            WHEN
                                @piezasPackA - valida1 = 2 AND
                                (SELECT TOP(1) tr.rankBen FROM (
                                    SELECT RANK() OVER( ORDER BY beneficio ASC) AS rankBen, beneficio FROM #PackA AS r
                                ) AS tr where tr.beneficio = temp.beneficio ) = 1
                                THEN packAR + 1
                            WHEN
                                @piezasPackA - valida1 = 2 AND
                                (SELECT TOP(1)  tr.rankBen FROM (
                                    SELECT RANK() OVER( ORDER BY beneficio ASC) AS rankBen, beneficio FROM #PackA AS r
                                ) AS tr where tr.beneficio = temp.beneficio ) = 2
                                THEN packAR + 1
                            ELSE packAR
                            END
                    )
                    ELSE packAR
                    END AS data
                FROM #PackA AS temp
            ) AS t
            WHERE p.ID = t.ide
        -- Guardamos Pack A en la tabla #Calculos
        UPDATE #Calculos
            SET packA = t.PackA
            FROM #Calculos AS v, (
                    SELECT packA, ID FROM #PackA
            ) AS t
            WHERE v.ID = t.ID
        UPDATE #PackA
            SET valida2 = t.data
            FROM (
                SELECT SUM(packA) AS data FROM #PackA
            )AS t
    /* FIN Calculo de Pack A*/

        -- Calculo compra Ideal
        UPDATE #Calculos
            SET compraIdeal = t.ideal
            FROM #Calculos AS p, (
                SELECT ID,
                ROUND(@forecast * share, 0) AS ideal
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID

    /* Calculos Pack B */
        -- Calculo  FORCAST * SHARE / PZ PK
        UPDATE #Calculos
            SET forecastSharePackA =
                        ceiling(
                        (CASE WHEN @forecast >= @minPzSKU
                        THEN
                            CompraIdeal * (1 - @porCompraSKU)

                        ELSE
                            CompraIdeal
                        END)
                        / NULLIF(packA,0))
        --Calculo Numero de Pack A
        UPDATE #Calculos
            SET numPackA = t.data								-- Cast numeric, roundup
            FROM #Calculos as p, (
                SELECT ID,
                CASE
                WHEN
                    (SELECT COUNT(share) FROM #Calculos WHERE share > 0) = 1
                    THEN CEILING(COALESCE(CAST(@forecast AS numeric(15,6)) / NULLIF(@piezasPackA,0),0))
                WHEN
                    @forecast < @minPzSKU AND @numMinTallas = 0
                    THEN CEILING(dbo.FUN_MAX(CAST(@forecast AS numeric(15,6))/@piezasPackA, @minimoTiendas))
                WHEN @forecast < @minPzSKU AND @numMinTallas <> 0 AND (
                        dbo.FUN_MAX(@minimoTiendas, (SELECT MIN(forecastSharePackA) FROM #Calculos)) *
                    @piezasPackA >= @forecast*0.99 OR
                    @forecast-(dbo.FUN_MAX(@minimoTiendas, (SELECT MIN(forecastSharePackA) FROM #Calculos))) *
                    @piezasPackA <= 15
                )
                THEN
                    --Version 13
                    CEILING(COALESCE(
                        CAST((CASE WHEN @forecast < (@piezasPackA * @minimoTiendas)
                        THEN
                            @piezasPackA * @minimoTiendas
                        ELSE
                            @forecast
                        END) AS NUMERIC(15,6))
                    / NULLIF(@piezasPackA,0),0))
                    --fin de version 13
                WHEN
                    @forecast < @minPzSKU AND @numMinTallas <> 0
                    THEN CEILING((dbo.FUN_MAX(@minimoTiendas, (SELECT MIN(forecastSharePackA) FROM #Calculos))))
                WHEN
                    @forecast >= @minPzSKU AND @numMinTallas = 0
                    THEN CEILING(COALESCE(dbo.FUN_MAX(@minimoTiendas, CAST((@forecast * (1 - @porCompraSKU))AS NUMERIC(15,6))/NULLIF(@piezasPackA,0)),0)) --modificado version13
                ELSE CEILING(dbo.FUN_MAX(@minimoTiendas, (SELECT MIN(forecastSharePackA) FROM #Calculos))) --modificado version 13
                END AS data
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        -- Calculo compraPackA
        UPDATE #Calculos
            SET compraPackA = t.compra
            FROM #Calculos AS p, (
                SELECT ID,
                (numPackA * packA) AS compra
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        --Calculos Tallas Pack B
        UPDATE #Calculos
            SET tallasPackB = t.dato
            FROM #Calculos as p, (
                SELECT c.ID,
                CASE
                WHEN @numMinTallas <= 0											-- Agregado cuando minimo de tallas es 0, tallasPackB = 0
                    THEN 0
                WHEN (SELECT SUM(compraPackA) FROM #Calculos) >= @forecast
                    THEN 0
                WHEN (
                    CASE WHEN c.share <= (
                        SELECT TOP(1) share FROM (
                            SELECT TOP(@numMinTallas) share FROM #Calculos ORDER BY share ASC
                        ) AS t ORDER BY share DESC)
                    THEN 'Quitar'
                    ELSE ''
                    END
                ) <> 'Quitar'
                    THEN (
                        CASE WHEN @forecast >= @minPzSKU
                        THEN compraIdeal * (1 - @porCompraSKU) -- Campo Cambiado - compraIdeal * shareMin --ideal -- compraIdeal * (1 - @porCompraSKU)
                        ELSE compraIdeal
                        END
                    ) - compraPackA
                ELSE 0
                END AS dato
                FROM #Calculos AS c Join #PackA AS p ON p.ID = c.ID
            ) AS t
            WHERE p.ID = t.ID
        --Calculo Share 1 Pack B
        UPDATE #Calculos
            SET share1PackB = t.data
            FROM #Calculos as p, (
                SELECT ID,(
                    (
                        (
                            CASE WHEN tallasPackB <> 0
                            THEN share
                            ELSE 0
                            END
                        ) * (
                            COALESCE((
                                1 -COALESCE( (SELECT SUM(tallasPackB) FROM #Calculos) / NULLIF(
                                    (SELECT SUM(compraIdeal) FROM #Calculos) -
                                    (SELECT SUM(compraPackA) FROM #Calculos)
                                ,0),0)
                            ) / NULLIF((SELECT SUM(share) FROM #Calculos WHERE tallasPackB <> 0),0),0)
                        )
                    ) + COALESCE(
                        tallasPackB / NULLIF(
                            (SELECT SUM(compraIdeal) FROM #Calculos) -
                            (SELECT SUM(compraPackA) FROM #Calculos)
                        ,0)
                    ,0)
                )AS data
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        --Calculo share 2 packB
        UPDATE #Calculos
            SET share2PackB = t.data
            FROM #Calculos as p, (
                SELECT ID, (
                    CASE WHEN COALESCE(share1PackB / NULLIF((SELECT SUM(share1PackB) FROM #Calculos),0),0) = 0
                    THEN  0
                    ELSE COALESCE(share1PackB / NULLIF((SELECT SUM(share1PackB) FROM #Calculos),0),0)
                    END
                ) as data
                FROM #Calculos
            )as t
            WHERE p.ID = t.ID
        --Calculo Share Pack B
        UPDATE #Calculos
            SET sharePackB = t.data
            FROM #Calculos as p, (
                SELECT ID,
                Case
                WHEN (SELECT COUNT(*) FROM #Calculos WHERE share2PackB <> 0)  = 0
                THEN 0
                WHEN (
                    share2PackB >=
                    (
                        SELECT TOP(1) share2PackB FROM (
                            SELECT TOP(@numMinTallas) share2PackB FROM #Calculos ORDER BY share2PackB DESC
                        ) AS t ORDER BY share2PackB ASC
                    )
                    AND share2PackB <= COALESCE(1/NULLIF(@piezasPackA*@porPackBvsPackA,0) * 0.5,0)
                )
                THEN COALESCE(1/NULLIF((@piezasPackA*@porPackBvsPackA),0),0)
                ELSE
                    COALESCE(share2PackB * ( 1 - (
                        (
                            SELECT COUNT(*) FROM #Calculos
                            WHERE share2PackB >= (
                                SELECT TOP(1) share2PackB FROM (
                                    SELECT TOP(@numMinTallas) share2PackB FROM #Calculos ORDER BY share2PackB DESC
                                ) AS t ORDER BY share2PackB ASC
                            ) AND share2PackB < COALESCE(1/NULLIF(@piezasPackA*@porPackBvsPackA,0)*0.5,0)
                        )* COALESCE(1/NULLIF(@piezasPackA*@porPackBvsPackA,0),0)
                    )) / NULLIF((
                        SELECT SUM(share2PackB) FROM #Calculos
                        WHERE share2PackB >= COALESCE(1/NULLIF(@piezasPackA*@porPackBvsPackA,0)*0.5,0)
                    ),0),0)
                END AS data
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        --Calculos Pack B													-- Campo Cambiado con la version 13
        UPDATE #Calculos
            SET packB = t.data
            FROM #Calculos as p,(
                SELECT
                    ID,
                    CASE WHEN (SELECT SUM(tallasPackB) FROM #Calculos) < 0 OR sharePackB < 0  --Add el OR para Evitar comprar -1 10/OCT/19
                        THEN 0
                    ELSE
                        COALESCE(ROUND((@piezasPackA * @porPackBvsPackA) * ROUND(sharePackB,1),0),0)
                    END
                    AS data
                    FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        --Calculo Numero de Pack B
        UPDATE #Calculos
            SET  numPackB = t.data
            FROM (
                SELECT
                CASE WHEN @forecast >= @minPzSKU
                    THEN COALESCE(ROUND((
                        (@forecast * (1 - @porCompraSKU)) - (SELECT SUM(compraPackA) FROM #Calculos)  --Cambio, se le agrego el 1 -
                    ) / NULLIF((SELECT SUM(packB) FROM #Calculos),0),0),0)
                    ELSE COALESCE(ROUND(
                        (@forecast-(SELECT SUM(compraPackA) FROM #Calculos)) /
                        NULLIF((SELECT SUM(packB) FROM #Calculos),0),0)
                    ,0)
                END AS data
                FROM #Calculos
            ) AS t
        --Calculo Compra Pack B
        UPDATE #Calculos
            SET  compraPackB = t.data
            FROM #Calculos as p, (
                SELECT ID,
                (numPackB * packB) AS data
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        -- SHARE SKU ----- NUEVO CAMPO EN VERSION 13
        UPDATE #Calculos
            SET shareSKU = t.data
            FROM #Calculos as p , (
                SELECT ID,
                CASE
                    WHEN @forecast < @minPzSKU
                        THEN 0
                    WHEN ((compraIdeal - ((numPackA * packA) + (packB * numPackB))) < 0)
                        THEN 0
                    ELSE
                        compraIdeal - ((numPackA * packA) + (packB * numPackB))
                END  AS data
                FROM #Calculos
            )AS t
            WHERE p.ID = t.ID
        --Calculamos el valor de SKU --Version 13
        UPDATE #Calculos
            SET skuVal = t.data
            FROM #Calculos as p ,(
                SELECT ID,
                ceiling(COALESCE(CAST(shareSKU AS DECIMAL(15,6)) / NULLIF((SELECT SUM(shareSKU) FROM #Calculos),0),0) * (@forecast - (SELECT SUM(compraPackA) + SUM(compraPackB) FROM #Calculos)))
                AS data
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
        --Calculo Pack Simple
        UPDATE #Calculos
            SET packSimple = t.data
            FROM #Calculos AS v, (
                    SELECT
                    ID,
                    Round(COALESCE(skuVal/NULLIF(@pzPackSimple,0),0),0) AS data
                FROM #Calculos
            ) as t
            WHERE v.ID = t.ID
        --Calculamos Compra Real
        UPDATE #Calculos
            SET  compraReal = t.data
            FROM #Calculos as p, (
                SELECT ID,
                (packA*numPackA)+(packB*numPackB)+(packSimple*@pzPackSimple) AS data
                FROM #Calculos
            ) AS t
            WHERE p.ID = t.ID
    /* FIN Calculos Pack B*/
    /* INICIO DE SPLITS */
        DECLARE @TIPO NVARCHAR(50)
        SET @TIPO = (SELECT top 1 Region FROM CAL_VIEW_Orders WHERE ID_DevelopmentStyleColor=@DevStyleColor)										-- PENDIENTE: obtener de ANDROMEDA DevelopmentStyleColor.Sourcing
        -- Tabla que guardará los porcentajes a usar
        IF OBJECT_ID('tempdb.dbo.#TempPorcentaje', 'U') IS NOT NULL
            DROP TABLE #TempPorcentaje ;
        CREATE TABLE #TempPorcentaje  (ID INT IDENTITY (1,1), paramCode NVARCHAR(20), paramValue DECIMAL(15,6))
            IF @TIPO = 'MEXICO'	-- Comprobamos si es nacional o importados y guardamos los porcentajes a usar
            BEGIN
                INSERT INTO #TempPorcentaje  SELECT paramCode, CAST(paramValue as DECIMAL) / 100 as paramValue FROM CAL_Params WHERE paramCode LIKE 'PorPedNac%' and season = @season and paramValue > 0
            END
            ELSE --IF @TIPO = 'IMPORTADO'
            BEGIN
                INSERT INTO #TempPorcentaje  SELECT paramCode, CAST(paramValue as DECIMAL) / 100 as paramValue FROM CAL_Params WHERE paramCode LIKE 'PorPedImp%' and season = @season and paramValue > 0
            END
            select * from #TempPorcentaje
        SELECT COUNT(*) as NumeroDeSplits FROM #TempPorcentaje
        -- Cuando estemos en los calculos del split 2 en adelante, realizamos un ciclo
        -- Calculo para PzXPackA, PzXPackB, PzXSKU, CompraRealSplit
        UPDATE #Calculos
            SET PzXPackA = (SELECT SUM(packA) FROM #Calculos),
                PzXPackB = (SELECT SUM(packB) FROM #Calculos),
                PzXSKU = 1, CompraRealSplit = (SELECT SUM(compraReal) FROM #Calculos)
        select @numMinTallas as minimoTallasQuitar
        -- TABLA TEMPORAL SPLIT
        IF OBJECT_ID('tempdb.dbo.#TempSplitsCursor', 'U') IS NOT NULL
            DROP TABLE #TempSplitsCursor ;
        CREATE TABLE #TempSplitsCursor  (ID INT IDENTITY (1,1), nameSplit NVARCHAR (20), size NVARCHAR (10), value NUMERIC(15,6), sku INT)
        --PRIMER PED PACK A
        INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
            SELECT '1PedPackA', size, (
                    CASE WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                        THEN
                            CASE WHEN ((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) > (numPackA * PzXPackA))
                            THEN
                                compraPackA
                            ELSE
                                COALESCE(CEILING((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) / NULLIF(PzXPackA,0)) * packA,0)
                            END
                    ELSE
                        compraPackA
                    END
            ) , sku FROM #Calculos as c
        --PRIMER PED PACK B
        INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
            SELECT '1PedPackB', size,(
                CASE WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                    THEN
                        CASE WHEN ((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) <= (SELECT sum(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedPackA'))
                        THEN
                            0
                        WHEN CEILING(((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) - (SELECT sum(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedPackA')) / NULLIF(PzXPackB,0)) > numPackB
                        THEN
                            COALESCE(NULLIF(numPackB * packB,0),0)
                        ELSE
                            COALESCE(NULLIF(CEILING(((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) - (SELECT sum(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedPackA')) / NULLIF(PzXPackB,0)) * packB,  0),0)
                        END
                    ELSE
                        compraPackB
                    END
            ),sku FROM #Calculos as c
        --PRIMER PED LC
        INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
            SELECT '1PedLC', size,(
                    CASE WHEN (SELECT SUM(skuVal) FROM #Calculos) = 0
                        THEN
                            0
                        WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                        THEN
                            CASE WHEN (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) <= ((SELECT sum(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedPackA') + (SELECT sum(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedPackB'))
                            THEN
                                COALESCE(0,0)
                            ELSE
                                CEILING(
                                    (
                                        CASE WHEN (((CompraReal * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1')) - ((SELECT value FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedPackA' and tsc.size = c.size) + (SELECT value FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedPackB' and tsc.size = c.size))) >= skuVal)
                                        THEN
                                            COALESCE(skuVal,0)
                                        ELSE
                                            COALESCE(CompraReal * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE 'PorPed%1'),0)
                                        END
                                    ) - (
                                        (SELECT value FROM #TempSplitsCursor AS tsc WHERE nameSplit = '1PedPackA' and tsc.size = c.size) + (SELECT sum(value) FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedPackB' and tsc.size = c.size)
                                    )
                                )
                            END
                        ELSE
                            skuVal
                        END
            ),sku FROM #Calculos as c
        --PRIMER PED SKU
        INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
            SELECT '1PedSKU', size,(
                    CASE WHEN (
                        CASE WHEN (SELECT SUM(skuVal) FROM #Calculos) = 0
                        THEN
                            0
                        WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                        THEN (
                            CASE WHEN (SELECT TOP 1 value FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedLC' AND tsc.size = c.size) <= 0
                            THEN
                                0
                            ELSE
                                COALESCE(CEILING((SELECT TOP 1 value FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedLC' AND tsc.size = c.size) / (SELECT SUM(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedLC' AND value > 0)),0)
                            END
                        ) * (SELECT TOP 1 value FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedLC' AND tsc.size = c.size)
                        ELSE
                            skuVal
                        END
                    ) > skuVal
                    THEN
                        skuVal
                    WHEN (SELECT SUM(skuVal) FROM #Calculos) = 0
                    THEN
                        0
                    WHEN CompraRealSplit >= @minPzSKU AND @comercialGroup = 'BASICO'
                        THEN  ROUND (
                            (
                                CASE WHEN (SELECT TOP 1value FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedLC' AND tsc.size = c.size) <= 0
                                THEN
                                    0
                                ELSE
                                    COALESCE((SELECT CAST(value AS DECIMAL) FROM #TempSplitsCursor as tsc WHERE nameSplit = '1PedLC' AND tsc.size = c.size) / NULLIF((SELECT CAST(SUM(value) AS DECIMAL) FROM #TempSplitsCursor WHERE nameSplit = '1PedLC' AND value > 0) ,0) ,0)
                                END
                            ) * (SELECT SUM(value) FROM #TempSplitsCursor WHERE nameSplit = '1PedLC' )
                        ,0)
                    ELSE
                        skuVal
                    END
            ),sku FROM #Calculos as c
        --select * from #TempSplitsCursor
        -- Declaramos el cursor
        DECLARE @id INT
        DECLARE @porcentaje DECIMAL(15,6)
        DECLARE CSPLIT CURSOR FOR
            SELECT ID, paramValue FROM #TempPorcentaje
        -- Calculamos el pedido por split
        OPEN CSPLIT
            FETCH NEXT FROM CSPLIT INTO @id , @porcentaje
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @id > 1
                BEGIN
                    --PED PACK A
                    INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
                        SELECT CONCAT(@id,'PedPackA'), size , (  --COALESCE( (select sum(value) from #TempSplitsCursor as tsc where tsc.size = c.size  and (nameSplit like '%A')),0)
                            CASE WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                            THEN
                                CASE WHEN (COALESCE( (select sum(value) from #TempSplitsCursor as tsc where (nameSplit like '%A')),0)) >= (SELECT SUM(compraPackA) FROM #Calculos)
                                THEN
                                    0
                                WHEN (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) >= ((SELECT SUM(compraPackA) FROM #Calculos) - (COALESCE( (select sum(value) from #TempSplitsCursor as tsc where (nameSplit like '%A')),0)))
                                THEN
                                    COALESCE(CEILING(((SELECT SUM(compraPackA) FROM #Calculos) - COALESCE((select sum(value) from #TempSplitsCursor as tsc where (nameSplit like '%A')),0)) / NULLIF(PzXPackA,0)) * packA,0)
                                ELSE
                                    COALESCE(CEILING((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) / NULLIF(PzXPackA,0)) * packA,0)
                                END
                            ELSE
                                0
                            END
                        ), sku FROM #Calculos as c
                    --PED PACK B
                    INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
                        SELECT CONCAT (@id,'PedPackB'), size,(
                            CASE WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                            THEN
                                CASE WHEN (COALESCE((SELECT SUM(value) FROM #TempSplitsCursor WHERE nameSplit LIKE CONCAT(@id,'%A')) ,0)) >= (CompraRealSplit * (SELECT TOP 1 paramValue FROM CAL_Params WHERE paramCode LIKE CONCAT('PorPed%',@id)))
                                THEN
                                    0
                                WHEN ((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) - (COALESCE((SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%A')) ,0))) >= ((SELECT SUM(compraPackB) FROM #Calculos) - (COALESCE((SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE '%B'),0)))
                                THEN
                                    COALESCE(CEILING(((SELECT SUM(compraPackB) FROM #Calculos) - COALESCE((SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE '%B'),0)) / NULLIF(PzXPackB,0)),0) * packB
                                ELSE
                                    COALESCE(CEILING(((CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) - (COALESCE((SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%A')) ,0))) / NULLIF(PzXPackB,0)) * packB,0)
                                END
                            ELSE
                                0
                            END
                        ), sku FROM #Calculos as c
                    -- PedLC
                    INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)										-- Arreglo general
                        SELECT CONCAT (@id,'PedLC'), size, (
                            CASE WHEN (SELECT SUM(skuVal) FROM #Calculos) = 0
                            THEN
                                0
                            WHEN CompraRealSplit >= @PzSplit AND @comercialGroup = 'BASICO'
                            THEN
                                CASE WHEN (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) <= (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND (nameSplit LIKE CONCAT(@id,'%A') OR nameSplit LIKE CONCAT(@id,'%B')))
                                THEN
                                    0
                                WHEN (compraReal * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) >= (skuVal - (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE '%SKU'))--(SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id)))
                                THEN
                                    CEILING(skuVal - (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE '%SKU'))
                                ELSE
                                    CEILING(
                                        (compraReal * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) - (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND (nameSplit LIKE CONCAT(@id,'%A') OR nameSplit LIKE CONCAT(@id,'%B')))
                                    )
                                END
                            ELSE
                                0
                            END
                        ), sku FROM #Calculos as c
                    -- PED SKU
                    INSERT INTO #TempSplitsCursor (nameSplit, size, value, sku)
                        SELECT CONCAT (@id,'PedSKU'), size, (
                            CASE WHEN (SELECT SUM(paramValue) FROM #TempPorcentaje WHERE ID <= @id) = 1
                            THEN
                                skuVal - (COALESCE( (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND (nameSplit LIKE '%SKU')),0))
                            WHEN (
                            (
                                CASE WHEN (SELECT SUM(skuVal) FROM #Calculos) = 0
                                    THEN
                                        0
                                    WHEN (CompraRealSplit >=  @PzSplit) AND (@comercialGroup = 'BASICO')
                                    THEN
                                        CASE WHEN (COALESCE( (SELECT value FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND (nameSplit LIKE CONCAT(@id,'%LC'))),0)) <= 0
                                        THEN
                                            0
                                        ELSE
                                            COALESCE(ROUND(
                                                    ((SELECT value FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE CONCAT(@id,'%LC')) / NULLIF((SELECT CAST(SUM(value) as Decimal) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC') AND value > 0),0)) * (
                                                    CASE WHEN (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC') ) > 0  OR  (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC')) < (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id)))
                                                    THEN
                                                        (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) - (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%A') OR nameSplit LIKE CONCAT(@id,'%B'))
                                                    ELSE
                                                            (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC'))
                                                    END
                                                    )
                                                ,0),0)
                                        END
                                    ELSE
                                        0
                                    END
                            )	> (skuVal -  (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE '%SKU'))
                            )
                            THEN
                                skuVal -  (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE '%SKU')
                            WHEN (SELECT SUM(skuVal) FROM #Calculos) = 0
                            THEN
                                0
                            WHEN (CompraRealSplit >=  @PzSplit) AND (@comercialGroup = 'BASICO')
                            THEN
                                CASE WHEN (SELECT value FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE CONCAT(@id,'%LC')) <= 0
                                THEN
                                0
                                ELSE
                                COALESCE(ROUND(
                                    ((SELECT value FROM #TempSplitsCursor AS tsc WHERE tsc.size = c.size AND nameSplit LIKE CONCAT(@id,'%LC')) / NULLIF((SELECT CAST(SUM(value) as Decimal) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC') AND value > 0),0)) * (
                                    CASE WHEN (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC') ) > 0  OR  (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC')) < (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id)))
                                    THEN
                                        (CompraRealSplit * (SELECT top 1 paramValue FROM #TempPorcentaje WHERE paramCode LIKE CONCAT('PorPed%',@id))) - (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%A') OR nameSplit LIKE CONCAT(@id,'%B'))
                                    ELSE
                                        (SELECT SUM(value) FROM #TempSplitsCursor AS tsc WHERE nameSplit LIKE CONCAT(@id,'%LC'))
                                    END
                                    )
                                ,0),0)
                            END
                            ELSE
                                0
                            END
                        ) , sku FROM #Calculos as c
                END
                FETCH NEXT FROM CSPLIT INTO @id , @porcentaje
            END
        CLOSE CSPLIT

        SELECT * FROM #Calculos
        SELECT * FROM #TempSplitsCursor
        select SUM(value) AS CompraTotal from #TempSplitsCursor where nameSplit NOT like '%LC'
    /* Insercion  de resultado en Tablas Pack y PackDetail */
        -- Declaracion variables globales
        DECLARE @idPorcentaje INT
        DECLARE @model NVARCHAR(10)
        DECLARE @versionPack INT
        DECLARE @PackID NUMERIC(15,0) = -1
        DECLARE @Name int = 65
        SET @model = (SELECT TOP(1) model FROM CAL_VIEW_Orders WHERE ID_DevelopmentStyleColor = @DevStyleColor)
        SELECT @versionPack = (MAX(versionPack)) FROM CAL_Pack WHERE styleColor = @DevStyleColor
        IF @versionPack is null
            set @versionPack = 0
        -------------------------------------
        UPDATE CAL_PACK
        SET ACTIVE = 0
        WHERE STYLECOLOR = @DEVSTYLECOLOR
        -------------------------------------
        -- Insertarmos el detalle de cada pack del modelo
        OPEN CSPLIT
            FETCH NEXT FROM CSPLIT INTO @idPorcentaje , @porcentaje
            WHILE @@FETCH_STATUS = 0
            BEGIN
            /* PACK A */
                IF (SELECT COUNT(*) FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%A') and value > 0) > 0
                BEGIN
                    SET @PackID = (
                        SELECT TOP(1) packId FROM (
                            SELECT packID, COUNT(*) AS total
                            FROM CAL_Pack AS P
                            JOIN CAL_PackDetail AS PD ON P.idPack = PD.idPack
                            JOIN (SELECT packA, size, sku, id_StyleSku FROM #Calculos) AS C ON C.packA = PD.quantityUnits AND C.id_StyleSku = PD.styleSku
                            GROUP BY packId, PD.idPack
                        ) AS P
                        WHERE P.total = (select COUNT(*) FROM  #Calculos)
                    )
                    select @PackID as packid

                    IF @PackID IS NULL OR @PackID = -1
                    BEGIN
                        -- Incrementamos la versión del pack
                        SET @versionPack = @versionPack + 1
                        SET @PackID = dbo.FUN_PACKID(@model, @VersionPack)
                    END

                    -- Insercion de pack
                    INSERT INTO CAL_Pack(
                        division, subDivision, comercialGroup, family, subFamily, season, typeSize, unitType,
                        totalUnitsInPack, totalPacksToOrder, styleColor, forecast, active, style, versionPack, orderNumber, packName, packId
                    )
                    VALUES(@division, @subDivision, @comercialGroup, @family, @subFamily, @season, @typeSize,1,
                        (SELECT SUM(packA) FROM #Calculos),
                        ((SELECT SUM(value) FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%A')) / (SELECT SUM(packA) FROM #Calculos)),
                        @DevStyleColor, @forecast, 1, @DevStyle, @versionPack, @idPorcentaje, CHAR(@Name), @PackID
                        )
                    -- obtenemos el id del elemento insertado
                    SET @id =  SCOPE_IDENTITY();

                    SELECT 'PACK A'
                    SELECT @id, packA, size, sku, id_StyleSku FROM #Calculos

                    INSERT INTO CAL_PackDetail (idPack, quantityUnits, size ,sku, styleSku)
                        SELECT @id, packA, size, sku, id_StyleSku FROM #Calculos
                    -- Incrementamos codigo ascii de nombre   
					SET @Name = @Name + 1                 
                    SELECT * FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%A')
                END
            /* FIN PACK A */
            /* PACK B */
                IF (SELECT COUNT(*) FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%B') and value > 0) > 0
                BEGIN

                    SET @PackID = (
                        SELECT TOP(1) packId FROM (
                            SELECT packID, COUNT(*) AS total
                            FROM CAL_Pack AS P
                            JOIN CAL_PackDetail AS PD ON P.idPack = PD.idPack
                            JOIN (SELECT packB, size, sku, id_StyleSku FROM #Calculos) AS C ON C.packB = PD.quantityUnits AND C.id_StyleSku = PD.styleSku
                            GROUP BY packId, PD.idPack
                        ) AS P
                        WHERE P.total = (select COUNT(*) FROM  #Calculos)
                    )
                    select @PackID as packid

                    IF @PackID IS NULL OR @PackID = -1
                    BEGIN
                        -- Incrementamos la versión del pack
                        SET @versionPack = @versionPack + 1
                        SET @PackID = dbo.FUN_PACKID(@model, @VersionPack)
                    END

                    INSERT INTO CAL_Pack(
                        division, subDivision, comercialGroup, family, subFamily, season, typeSize, unitType,
                        totalUnitsInPack, totalPacksToOrder, styleColor, forecast, active, style, versionPack, orderNumber, packName, packId
                    )
                    VALUES(@division, @subDivision, @comercialGroup, @family, @subFamily, @season, @typeSize,1,
                        (SELECT SUM(packB) FROM #Calculos),
                        ((SELECT SUM(value) FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%B')) / (SELECT SUM(packB) FROM #Calculos)),
                        @DevStyleColor, @forecast, 1, @DevStyle, @versionPack, @idPorcentaje, CHAR(@Name), @PackID
                        )
                    -- obtenemos el id del elemento insertado
                    SET @id =  SCOPE_IDENTITY()

                    SELECT 'PACK B'
                        SELECT @id , packB, size, sku, id_StyleSku FROM #Calculos

                    -- Insersion de pack detail
                    INSERT INTO CAL_PackDetail (idPack, quantityUnits, size ,sku, styleSku)
                        SELECT @id , packB, size, sku, id_StyleSku FROM #Calculos
                    -- Incrementamos codigo ascii de nombre
					SET @Name = @Name + 1
                    SELECT * FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%B')
                END
            /* FIN PACK B */
            /* SKU */
                IF (SELECT COUNT(*) FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%SKU') and value > 0) > 0
                BEGIN
                    INSERT INTO CAL_Pack(
                        division, subDivision, comercialGroup, family, subFamily, season, typeSize, unitType,
                        totalUnitsInPack, totalPacksToOrder, styleColor, forecast, active, style, orderNumber, packName
                    )
                    VALUES(@division, @subDivision, @comercialGroup, @family, @subFamily, @season, @typeSize,2,
                        (SELECT SUM(value) FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%SKU')),
                        1, @DevStyleColor, @forecast, 1, @DevStyle, @idPorcentaje, CHAR(@Name)
                        )
                    -- obtenemos el id del elemento insertado
                    SET @id =  SCOPE_IDENTITY()
                    -- Actualizacion de IdPack y PackName Perron
                    UPDATE CAL_Pack
                        SET
                            packId = idPack
                        WHERE idPack = @id
                    -- Insersion de pack detail
                    INSERT INTO CAL_PackDetail (idPack, quantityUnits, size ,sku, styleSku)
                        SELECT @id, value, size, sku, (SELECT id_StyleSku FROM #Calculos as c where c.size = tsc.size)
                        FROM #TempSplitsCursor as tsc
                        WHERE nameSplit like CONCAT(@idPorcentaje,'%SKU')
                    -- Incrementamos codigo ascii de nombre
					SET @Name = @Name + 1
                    SELECT * FROM #TempSplitsCursor WHERE nameSplit like CONCAT(@idPorcentaje,'%SKU')
                END
            /* FIN SKU */
                SELECT @idPorcentaje, @porcentaje
                FETCH NEXT FROM CSPLIT INTO @idPorcentaje , @porcentaje
            END
        CLOSE CSPLIT
        DEALLOCATE CSPLIT

		/* ESTABLECER PACK NAME POR ORDEN DE PACKID ASC */				
			DECLARE @order INT
			SET @Name = 65
			-- Declaramos el cursor	
			DECLARE CORDERS CURSOR FOR
				SELECT DISTINCT(orderNumber) FROM CAL_Pack WHERE styleColor = @DevStyleColor AND active = 1 ORDER BY orderNumber ASC
			-- Establecemos el packName
			OPEN CORDERS
				FETCH NEXT FROM CORDERS INTO @order
				WHILE @@FETCH_STATUS = 0
				BEGIN
					DECLARE CPACKSORDERS CURSOR FOR
						SELECT idPack FROM CAL_Pack WHERE styleColor = @DevStyleColor AND active = 1 AND orderNumber = @order AND unitType = 1 
						ORDER BY packId ASC
					OPEN CPACKSORDERS
						FETCH NEXT FROM CPACKSORDERS INTO @id
						WHILE @@FETCH_STATUS = 0
						BEGIN 
							UPDATE CAL_Pack SET packName = CHAR(@Name) WHERE idPack = @id
							SET @Name = @Name + 1
							FETCH NEXT FROM CPACKSORDERS INTO @id
						END
					CLOSE CPACKSORDERS
					DEALLOCATE CPACKSORDERS
					IF EXISTS (SELECT * FROM CAL_Pack WHERE styleColor = @DevStyleColor AND active = 1 AND orderNumber = @order AND unitType = 2)
					BEGIN
						SET @Name = @Name + 1
					END
					FETCH NEXT FROM CORDERS INTO @order
				END
			CLOSE CORDERS
			DEALLOCATE CORDERS
		/* FIN ESTABLECER PACK NAME POR ORDEN DE PACKID ASCENDENTE */

        INSERT INTO CAL_LogCalculate(dateExecution, model, descriptionLog)
        VALUES (GETDATE(), @DevStyleColor, 'Calculos Ejecutados: Se Realizaron los calculos y se generaron los packs con packID')

        /* PLM E INTEGRACIONES */
            IF (SELECT COUNT(*) FROM CAL_PACK WHERE STYLECOLOR = @DEVSTYLECOLOR AND ACTIVE = 1 ) > 0
            BEGIN
                EXEC SP_CAL_INSERTPACKS @RESULT, @DEVELOPMENTSTYLECOLORID=@DEVSTYLECOLOR, @DEVELOPMENTSTYLEID=@DEVSTYLE, @FORECAST=@FORECAST, @MODEL = @MODEL
            END
            ELSE
            BEGIN
                SET @RESULT = 'CAL: NO SE PUDIERON GUARDAR LOS DATOS CALCULADOS'
            END
        /* FIN PLM E INTEGRACIONES */

    /* FIN Insercion  de resultado en Tablas Pack y PackDetail */

    /* Eliminacion de tablas temporales */
        IF OBJECT_ID('tempdb.dbo.#TempSplitsCursor', 'U') IS NOT NULL
            DROP TABLE #TempSplitsCursor ;
        IF OBJECT_ID('tempdb.dbo.#TempPorcentaje', 'U') IS NOT NULL
            DROP TABLE #TempPorcentaje;
        IF OBJECT_ID('tempdb.dbo.#PackA', 'U') IS NOT NULL
            DROP TABLE #PackA;
        IF OBJECT_ID('tempdb.dbo.#Calculos', 'U') IS NOT NULL
            DROP TABLE #Calculos;
    /* FIN Eliminacion de tablas temporales */

        RETURN
    END TRY
    BEGIN CATCH
        INSERT INTO CAL_LogCalculate(dateExecution, model, descriptionLog)
        VALUES (GETDATE(), @DevStyleColor, error_message())
        PRINT error_message()
    END CATCH
END
GO
