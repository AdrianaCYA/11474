var columEdit = false;
var permissionExport = false;

$(function () {

    $('#selTamanioPaginas').change(function () {
        MVCGrid.setPageSize('DashboardGrid', $('#selTamanioPaginas').val());
    });
    $('#selTamanioPaginas').val(MVCGrid.getPageSize('DashboardGrid'));

    $('#Exportar').click(function () {
        if (!permissionExport) {
            MensajeError("No tiene permisos para exportar");
            return;
        }
        MensajeInfo("Exportando datos");
        removeColums();
        location.href = MVCGrid.getExportUrl('DashboardGrid');
        setColumGridPermission();
        return true;
    });

    $("#CargarDatos").click(function () {
        var semanas = document.getElementById("Semanas");
        if (!Validador.validarMayorCero(semanas)) {
            MensajeError("Numero de semanas incorrecto");
            return false;
        }
        if ($("select#TemporadaTeradata").val() == "") {
            MensajeError("Temporada invalida");
            return false;
        }
        iniciarModal("confirmacionModal");   
    });

    pantalla = document.getElementById("cronometro");

    $('#Filtro').click(function () {
        consultar();
    });

    $("#Semanas").change(function () {
        Validador.validarMayorCero(this);
    });

    $("#ActualizarShare").click(function () {
        actualizarShare();
    });

    $("div#NuevoShare").click(function () {
        iniciarModal("shareModalAdd");
    });

    $("#selDivision").change(function () {
        limpiarSelects("selDivision");
        $("#selDivision option:selected").each(function () {
            cargarSubDivision($("#selDivision option:selected").text());
        });
    });
    $("#selSubDivision").change(function () {
        limpiarSelects("selSubDivision");
        $("#selSubDivision option:selected").each(function () {
            cargarGrupo(
                $("#selDivision option:selected").text(),
                $("#selSubDivision option:selected").text()
            );
        });
    });
    $("#selGrupo").change(function () {
        limpiarSelects("selGrupo");
        $("#selGrupo option:selected").each(function () {
            cargarFamilia(
                $("#selDivision option:selected").text(),
                $("#selSubDivision option:selected").text(),
                $("#selGrupo option:selected").text()
            );
        });
    });
    $("#selFamilia").change(function () {
        limpiarSelects("selFamilia");
        $("#selFamilia option:selected").each(function () {
            cargarSubFamilia(
                $("#selDivision option:selected").text(),
                $("#selSubDivision option:selected").text(),
                $("#selGrupo option:selected").text(),
                $("#selFamilia option:selected").text()
            );
        });
    });

    $("#selTipoTalla").change(function () {
        $("#selTipoTalla option:selected").each(function () {
            generarCamposShareSize($("#selTipoTalla option:selected").text());
        });
    });

    $("#clearEC").click(function () {
        limpiarSelects("");
    });

    $("button.CancelarShare").click(function () {
        limpiarModalShare();
    });

    $("#AgregarShare").click(function () {
        validarAgregarShare();
    });

    cargarTemporadas();
    filtros();
    cargaDivision();
    cargarTipoTalla();
    setColumGridPermission();
});


/* Permission for edit and remove */
function setPermission(edit,exportP) {
    columEdit = (edit == 'True');
    permissionExport = (exportP == 'True');
    setColumGridPermission();
}

function iniciarModal(nombreModal) {
    $("#" + nombreModal).modal({ backdrop: 'static', keyboard: false });
    $("#" + nombreModal).modal('show');
}

function terminarModal(nombreModal) {
    $("#" + nombreModal).modal('hide');
}

/* Cronometro */
function iniciarCronometro() {
    timeInicial = new Date();
    control = setInterval(cronometro, 10);
}

function detenerCronometro() {
    clearInterval(control);
    pantalla.innerHTML = "00 : 00 : 00 : 00";
}

function cronometro() {
    timeActual = new Date();
    acumularTime = timeActual - timeInicial;
    acumularTime2 = new Date();
    acumularTime2.setTime(acumularTime);
    cc = Math.round(acumularTime2.getMilliseconds() / 10);
    ss = acumularTime2.getSeconds();
    mm = acumularTime2.getMinutes();
    hh = acumularTime2.getHours() - 18;
    if (cc < 10) { cc = "0" + cc; }
    if (ss < 10) { ss = "0" + ss; }
    if (mm < 10) { mm = "0" + mm; }
    if (hh < 10) { hh = "0" + hh; }
    pantalla.innerHTML = hh + " : " + mm + " : " + ss + " : " + cc;
}

function confirmacionTeradata() {
    iniciarModal("confirmacionModal");    
}

/* Conectamos con el controller para traer informacion de terada y cargarla en el grid */
function cargarTeradata(urlIni) {
    if (urlIni == null || urlIni == '')
        urlIni = '/';
    terminarModal("confirmacionModal");
    iniciarModal("historicoModal");
    iniciarCronometro();
    
    url = urlIni + "Dashboard/Consultar";
    var temporada = $("#TemporadaTeradata").val();
    var semanas = $("#Semanas").val(); 
    var datos = {
        temporada: temporada,
        semanas: semanas
    };
    MensajeInfo("Cargando historico");
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            terminarModal("historicoModal");
            detenerCronometro();
            if (data == true) {
                MVCGrid.setParamDistinct('DashboardGrid', "Temporada", $("#TemporadaTeradata").val());
                MensajeSuccess("Historico cargado"); 
                cargarTemporadas();
            }
            else {
                MensajeWarning("Existe una carga de historico en progreso");
            }
        },
        error: function (e) {
            terminarModal("historicoModal");
            detenerCronometro();
            MensajeError( "Error al cargar los datos");
        }
    });
    return false;
}

/* filtro */
function filtros() {
    $("input#Division").change(function () {
        consultar();
    });
    $("input#Subdivision").change(function () {
        consultar();
    });
    $("input#Grupo").change(function () {
        consultar();
    });
    $("input#Familia").change(function () {
        consultar();
    });
    $("input#Subfamilia").change(function () {
        consultar();
    });
    $("select#Temporada").change(function () {
        consultar();
    });
}
function consultar() {
    $("#Filtro").removeClass("open");
    $("#FiltroBoton").attr("aria-expanded", false);
    MVCGrid.setFiltersButton("DashboardGrid");
}

/* Editar Share */
function limpiarModalShare() {
    limpiarSelects();
    $("tbody#tablaShareAdd").empty();
    $("tfoot#tablaShareAdd").empty();
    $("tbody#tablaShare").empty();
    $("tfoot#tablaShare").empty();
    $("select#selTipoTalla").val("");
}

function editarShareVentana(idVentas) {
    cargarDatosShare(idVentas);
    iniciarModal("shareModal");
}

function cargarDatosShare(idVentas) {
    url = inicioUrl + "Dashboard/ConsultarShare";
    var datos = {
        idVentas: idVentas
    };
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            llenarTablaShare(data);
        },
        error: function (e) {
            terminarModal("shareModal");
            MensajeError("Error al cargar los datos");
        }
    });
    return false;
}

function llenarTablaShare(data) {
    $("tbody#tablaShare").empty();
    $("tfoot#tablaShare").empty();
    // si tiene respuesta sin datos
    var count = data.length;
    if (count <= 0) {
        MensajeError("No se encontro Share para actualizar");
    }
    // llenamos los campos de la EC
    $("#lblDivision").text(data[0]["division"]);
    $("#lblSubDivision").text(data[0]["subDivision"]);
    $("#lblGrupo").text(data[0]["comercialGroup"]);
    $("#lblFamilia").text(data[0]["family"]);
    $("#lblSubFamilia").text(data[0]["subFamily"]);
    $("#lblTemporada").text(data[0]["season"]);
    $("#lblTipoTalla").text(data[0]["typeSize"]);

    var suma = 0;
    for (var i = 0; i < count; i++) {
        var fila =
            "<tr>" +
            "   <th class='col-md-3'>" + (1 + i) + "</th>" +
            "   <th class='col-md-4' id='size'>" + data[i]["size"] + "</th>" +
            "   <th id='share'>" +
            "       <input value='" + data[i]["share"] + "' class='form-control text-box edit' id='" + (1 + i) + "'/>" +
            "   </th>" +
            "</tr>";
        $("tbody#tablaShare").append(fila);
        suma += parseFloat(data[i]["share"]);
    }
    var total =
        "<tr>" +
        "   <th colspan='2'>Total</th>" +
        "   <th>" +
        "       <input value='" + suma.toFixed(6) + "' class='form-control' id='total' disabled/>" +
        "   </th>" +
        "</tr>";
    $("tfoot#tablaShare").append(total);

    eventoInputsShare();
    validarShare();
    iniciarModal("shareModal");

}

function sumaShare() {
    var inputs = $("input.text-box.edit");
    var suma = 0; 

    for (var i = 0; i < inputs.length; i++) {
        if (inputs[i].value != "" && parseFloat(inputs[i].value) > 0 && parseFloat(inputs[i].value) <= 100)
            suma += parseFloat(inputs[i].value);
    }
    $("input#total").val(suma.toFixed(6));
}

function shareIguales() {
    var inputs = $("input.text-box.edit");
    var suma = 0;
    var diferentes = true;
    var array = [];
    for (var i = 0; i < inputs.length; i++) {
        if (inputs[i].value != "" && inputs[i].value >= 0 /*&& inputs[i].value <= 100*/) {
            for (var j = 0; j < inputs.length; j++) {
                if (inputs[j].value != "" && inputs[j].value >= 0 /*&& inputs[j].value <= 100*/) {
                    if (i != j && inputs[i].value === inputs[j].value) {

                        array.push(inputs[j].value);
                        Validador.Error(inputs[i]);
                        Validador.Error(inputs[j]);


                    }
                    else if (array.find(function (x) { return x == inputs[j].value; }) == undefined && Validador.validarShare(inputs[j]) && Validador.validarDatosPorcentaje(inputs[j])) {
                        Validador.Exito(inputs[j]);

                    }
                }
            }
        }
    }
    if (array.length > 0)
        MensajeWarning("No puede existir Share iguales");
    return diferentes;
}

function validarShare() {
    var input = document.getElementById("total")
    var suma = parseFloat($("#total").val());
    if (suma < 99.999999 || suma > 100.000001) {
        Validador.Error(input)
        return false;
    }
    Validador.Exito(input);
    return true;
}

function eventoInputsShare() {
    var inputs = $("input.text-box");
    var input;
    for (var i = 0; i < inputs.length; i++) {
        input = inputs[i];
        $("input[id='" + input.id + "']").bind("change", function () {
            sumaShare();
            Validador.validarDatosPorcentaje(this);
            shareIguales();
            //  Validador.validarShare(this);

            validarShare();
        });
    }
}

function actualizarShare() {
    if (!validarShareFinal())
        return false;
    
    url = inicioUrl + "Dashboard/ActualizarShare";
    var datos = {
        division: $("#lblDivision").text(),
        subdivision: $("#lblSubDivision").text(),
        grupo: $("#lblGrupo").text(),
        familia: $("#lblFamilia").text(),
        subfamilia: $("#lblSubFamilia").text(),
        temporada: $("#lblTemporada").text(),
        tipotalla: $("#lblTipoTalla").text(),
        share: getShareTabla()
    };
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            MVCGrid.reloadGrid("DashboardGrid");
            MensajeSuccess("Datos actualizados");
            terminarModal("shareModal");
        },
        error: function (e) {
            terminarModal("shareModal");
            MensajeError("Error al actualizar los datos");
        }
    });
    return false;
}

function validarShareFinal() {
    var inputs = $("input.text-box");
    for (var i = 0; i < inputs.length; i++) {
        if ($("#" + inputs[i].id).parent().hasClass("has-error")) {
            MensajeError("Error en el Share");
            return false;
        }
    }
    if ($("input#total").parent().hasClass("has-error")) {
        MensajeError("La suma de Share debe dar 100");
        return false;
    }
    return true;
}

function getShareTabla() {
    var shareObj = [];
    var sizes = $("th#size");
    var shares = $("th#share");

    for (var i = 0; i < sizes.length; i++) {
        item = {};
        item["size"] = sizes[i].innerHTML;
        item["share"] = parseFloat(shares[i].children[0].value);
        shareObj.push(item);
    }
    return shareObj;
}

/* Agregar Share */

function limpiarSelects(campo = "") {
    if (campo == "selFamilia")
        $("#selSubFamilia option").remove();
    else if (campo == "selGrupo") {
        $("#selSubFamilia option").remove();
        $("#selFamilia option").remove();
    }
    else if (campo == "selSubDivision") {
        $("#selSubFamilia option").remove();
        $("#selFamilia option").remove();
        $("#selGrupo option").remove();
    }
    else if (campo == "selDivision") {
        $("#selSubFamilia option").remove();
        $("#selFamilia option").remove();
        $("#selGrupo option").remove();
        $("#selSubDivision option").remove();
    }
    else if (campo == "") {
        $("#selSubFamilia option").remove();
        $("#selFamilia option").remove();
        $("#selGrupo option").remove();
        $("#selSubDivision option").remove();
        $("#selDivision").val("");
        $("#selTemporada").val("");
    }
}
function cargarDatos(datos, url, select) {
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            data.sort();
            llenarSelect(select, data);
        },
        error: function (e) {
            MensajeError("Problema al actualizar los datos");
        }
    });
    return false;
}

function llenarSelect(nombreSelect, arreglo) {
    $("#" + nombreSelect + " option").remove();
    $("#" + nombreSelect).append("<option value=''></option>");
    $.each(arreglo, function (key, value) {
        $("#" + nombreSelect).append("<option value='" + value + "'>" + value + "</option>");
    });
}

function cargarTemporadas() {
    url = inicioUrl + "Dashboard/GetTemporadas";
    var datos = {
    };
    cargarDatos(datos, url, "Temporada");
    return false;
}

function cargaDivision() {
    url = inicioUrl + "Dashboard/ConsultarDivision";
    var datos = {
    };
    cargarDatos(datos, url, "selDivision");
}

function cargarSubDivision(division) {
    url = inicioUrl + "Dashboard/ConsultarSubDivision";
    var datos = {
        division: division
    };
    cargarDatos(datos, url, "selSubDivision");
}

function cargarGrupo(division, subdivision) {
    url = inicioUrl + "Dashboard/ConsultarGrupo";
    var datos = {
        division: division,
        subdivision: subdivision
    };
    cargarDatos(datos, url, "selGrupo");
}

function cargarFamilia(division, subdivision, grupo) {
    url = inicioUrl + "Dashboard/ConsultarFamilia";
    var datos = {
        division: division,
        subdivision: subdivision,
        grupo: grupo
    };
    cargarDatos(datos, url, "selFamilia");
}

function cargarSubFamilia(division, subdivision, grupo, familia) {
    url = inicioUrl + "Dashboard/ConsultarSubFamilia";
    var datos = {
        division: division,
        subdivision: subdivision,
        grupo: grupo,
        familia: familia
    };
    cargarDatos(datos, url, "selSubFamilia");
}

function cargarTipoTalla() {
    url = inicioUrl + "Dashboard/ConsultarTipoTalla";
    var datos = {};
    cargarDatos(datos, url, "selTipoTalla");
}

function generarCamposShareSize(tipoTalla) {
    url = inicioUrl + "Dashboard/ConsultarTallas";
    var datos = {
        tipoTalla: tipoTalla
    };
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            generarTablaAddShare(data);
        },
        error: function (e) {
            MensajeError("Problema al actualizar los datos");
        }
    });
    return false;
}

function generarTablaAddShare(data) {
    $("tbody#tablaShareAdd").empty();
    $("tfoot#tablaShareAdd").empty();
    // si tiene respuesta sin datos
    var count = data.length;

    var suma = 0;
    for (var i = 0; i < count; i++) {
        var fila =
            "<tr>" +
            "   <th class='col-md-3'>" + (1 + i) + "</th>" +
            "   <th class='col-md-4' id='size'>" + data[i] + "</th>" +
            "   <th id='share'>" +
            "       <input value='' class='form-control text-box edit' id='" + (1 + i) + "'/>" +
            "   </th>" +
            "</tr>";
        $("tbody#tablaShareAdd").append(fila);
    }
    var total =
        "<tr>" +
        "   <th colspan='2'>Total</th>" +
        "   <th>" +
        "       <input value='0' class='form-control' id='total' disabled/>" +
        "   </th>" +
        "</tr>";
    $("tfoot#tablaShareAdd").append(total);

    eventoInputsShare();
    //validarShare();
    iniciarModal("shareModalAdd");

}

function validarAgregarShare() {
    validarShare();
    var selects = $("select.selectAdd");
    for (var i = 0; i < selects.length; i++) {
        if ($("#" + selects[i].id).val() == "") {
            MensajeError("Faltan datos por llenar");
            return false;
        }
    }

    var inputs = $("input.text-box.edit");
    for (var i = 0; i < inputs.length; i++) {
        if (!$("#" + inputs[i].id).parent().hasClass("has-success")) {
            MensajeError("Error en el Share");
            return false;
        }
    }
    if ($("input#total").parent().hasClass("has-error")) {
        MensajeError("La suma de Share debe dar 100");
        return false;
    }
    agregarShare();
    return true;

}
function agregarShare() {
    url = inicioUrl + "Dashboard/AgregarShare";
    var datos = {
        division: $("#selDivision").val(),
        subdivision: $("#selSubDivision").val(),
        grupo: $("#selGrupo").val(),
        familia: $("#selFamilia").val(),
        subfamilia: $("#selSubFamilia").val(),
        temporada: $("#selTemporada").val(),
        tipotalla: $("#selTipoTalla").val(),
        share: getShareTabla()
    };
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            if (data == "1")
                MensajeError("Ya existe hisotico con esos datos");
            else if (data == "") {
                cargarTemporadas();
                MensajeSuccess("Datos agregados");
                terminarModal("shareModalAdd");
                limpiarModalShare();
            }
            else {
                terminarModal("shareModalAdd");
                MensajeError("Error al actualizar los datos");
                limpiarModalShare();
            }
        },
        error: function (e) {
            terminarModal("shareModalAdd");
            MensajeError("Error al actualizar los datos");
        }
    });
    return false;
}

/**
 * Remove columns edit and delete of grid 
 */
function removeColums() {
    MVCGrid.setColumnVisibility('DashboardGrid', { "Edit": false });
}
/**
 * Remove column edit of grid 
 */
function setColumGridPermission() {
    MVCGrid.setColumnVisibility('DashboardGrid',
        {
            "Division": true,
            "Subdivision": true,
            "Grupo": true,
            "Familia": true,
            "Subfamilia": true,
            "Temporada": true,
            "Talla": true,
            "TipoTalla": true,
            "Ventas": true,
            "Share": true,
            "Edit": columEdit
        });
}