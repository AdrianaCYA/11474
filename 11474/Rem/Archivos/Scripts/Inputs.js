var season = "";
const NACIONAL = "PORPEDNAC";
const IMPORTADO = "PORPEDIMP";

$(function () {
    $("select#Temporada").change(function () {
        if (this.value == "") {
            $("select#Anio").empty();
            cambioTemporada("", "");
            return;
        }
        cargarAnioTemporadas(this.value);
    });

    $("select#Anio").change(function () {
        cambioTemporada($("select#Temporada").val(), this.value);
    });

    $("#btnActualizar").click(function () {
        if (!validarParametros())
            return false;
        actualizarParametros();
    });

    $("#btnTemporada").click(function () {
        agregarParametrosTemporada();
    });
    cargarTemporadas();
});

function cargarTemporadas() {
    url = inicioUrl + "Inputs/GetTemporadas";
    $.ajax({
        type: "POST",
        url: url,
        success: function (data) {
            if (data.length == 0) {
                MensajeWarning("No hay parámetros para temporada");
                return false;
            }
            llenarTemporadas(data,"Temporada");
        },
        error: function (e) {
            alert(e.responseText);
        }
    });
}

function cargarAnioTemporadas(temporada) {
    url = inicioUrl + "Inputs/GetAnioTemporadas";
    $.ajax({
        type: "POST",
        url: url,
        data: { temporada: temporada },
        success: function (data) {
            if (data.length == 0) {
                MensajeWarning("No hay parámetros para temporada");
                return false;
            }
            llenarTemporadas(data,"Anio");
        },
        error: function (e) {
            alert(e.responseText);
        }
    });
}

function llenarTemporadas(temporadas, nameSelect) {
    $("select#" + nameSelect).empty();
    var select = $("select#" + nameSelect);
    $("select#" + nameSelect).append('<option value=""></option>');
    for (var i = 0; i < temporadas.length; i++) {
        var temporada = '<option value="' + temporadas[i] + '">' + temporadas[i] +'</option>';
        $("select#" + nameSelect).append(temporada);
    }
}

function cambioTemporada(temporada, anio) {
    season = temporada + anio;
    url = inicioUrl + "Inputs/GetParametros";
    $.ajax({
        type: "GET",
        url: url,
        data: { temporada: temporada+anio },
        success: function (data) {
            $('#contenedor').html(data);
            if ($("#contenedor div div").length != 0) {
                cargarEventoInputs();
                $("strong#totalPedidosImportado")[0].innerHTML = sumaPorcentajePedidos(IMPORTADO) + " %";
                $("strong#totalPedidosNacional")[0].innerHTML = sumaPorcentajePedidos(NACIONAL) + " %";
                $('select#Temporada').val(temporada);
                $("select#Anio").val(anio);
            }
        },
        error: function (e) {
            alert(e.responseText);
        }
    });
    return false;
}

function cargarEventoInputs() {
    var inputs = $("input.text-box");
    var input;
    for (var i = 0; i < inputs.length; i++) {
        input = inputs[i];
        if (input.name.toUpperCase().indexOf("POR") > -1) {
            if (input.name.toUpperCase().indexOf(NACIONAL) > -1) {
                if (input.value == "0")
                    input.disabled = true;
                $("input[name='" + input.name + "']").bind("change", function () {
                    validarPorcentajePedidos(this, NACIONAL);
                });
            }
            if (input.name.toUpperCase().indexOf(IMPORTADO) > -1) {
                if (input.value == "0")
                    input.disabled = true;
                $("input[name='" + input.name + "']").bind("change", function () {
                    validarPorcentajePedidos(this, IMPORTADO);
                });
            }
            else {
                $("input[name='" + input.name + "']").bind("change", function () {
                    Validador.validarDatosPorcentaje(this);
                });

            }
        }
        else {
            $("input[name='" + input.name + "']").bind("change", function () {
                Validador.validarDatos(this)
            });
        }
    }
}

/**
 * Validamos los datos que son de tipo porcentaje pero son usados para pedidos nacionales
 * @param {any} input
 * @param {string} tipo
 * @returns {boolean}
 */
function validarPorcentajePedidos(input, tipo) {

    var porcentaje = sumaPorcentajePedidos(tipo);
    var nombreTotalPedido = "totalPedidosNacional";

    if (!Validador.validarDatosPorcentaje(input)) {
        porcentaje = sumaPorcentajePedidos(tipo);
        $("#" + nombreTotalPedido)[0].innerHTML = porcentaje + " %";
        $("#" + nombreTotalPedido)[0].parentElement.classList.add("alert-danger");
        $("#" + nombreTotalPedido)[0].parentElement.classList.remove("alert-success");
        return;
    }
    if (tipo == IMPORTADO)
        nombreTotalPedido = "totalPedidosImportado";
    $("#" + nombreTotalPedido)[0].innerHTML = porcentaje + " %";

    if (porcentaje == 100) {
        bloquearInputsPedidos(tipo);
        if (tipo + "1" == input.name.toUpperCase() && porcentaje != 100)
            habilitarSiguienteInputPed(tipo);

        porcentaje = sumaPorcentajePedidos(tipo);
        $("#" + nombreTotalPedido)[0].innerHTML = porcentaje + " %";
        if (porcentaje == 100) {
            $("#" + nombreTotalPedido)[0].parentElement.classList.remove("alert-danger");
            $("#" + nombreTotalPedido)[0].parentElement.classList.add("alert-success");
            return;
        }

        habilitarSiguienteInputPed(tipo);

    }
    else if (porcentaje < 100) {
        bloquearInputsPedidos(tipo);
        habilitarSiguienteInputPed(tipo);
        porcentaje = sumaPorcentajePedidos(tipo);
        $("#" + nombreTotalPedido)[0].innerHTML = porcentaje + " %";
        if (porcentaje == 100) {
            $("#" + nombreTotalPedido)[0].parentElement.classList.add("alert-success");
            $("#" + nombreTotalPedido)[0].parentElement.classList.remove("alert-danger");
            return;
        }
    }
    if (porcentaje != 100) {

        porcentaje = sumaPorcentajePedidos(tipo);
        $("#" + nombreTotalPedido)[0].innerHTML = porcentaje + " %";
        $("#" + nombreTotalPedido)[0].parentElement.classList.add("alert-danger");
        $("#" + nombreTotalPedido)[0].parentElement.classList.remove("alert-success");
    }
}

/**
 * Función que suma los porcentajes de pedidos nacional
 * @return {decimal}
 */
function sumaPorcentajePedidos(tipo) {
    var suma = 0;
    var input;
    var inputs = $("input.text-box");
    for (var i = 0; i < inputs.length; i++) {
        input = inputs[i];
        if (input.name.toUpperCase().indexOf(tipo) > -1 && input.value > 0 ) {
            suma += Number(input.value);
        }
    }
    return suma;
}

/**
 * Función que bloquea los inputs de pedidos nacional cuando el porcentaje es 100
 */
function bloquearInputsPedidos(tipo) {
    var i;
    var input;
    var inputs = $("input.text-box");
    for (i = 1; i < inputs.length; i++) {
        input = inputs[i];
        if (input.name.toUpperCase().indexOf(tipo) > -1 ) {
            if (input.value == 0 || input.disabled) {
                break;
            }
        }
    }
    for (j = i; j < inputs.length; j++) {
        input = inputs[j];
        if (input.name.toUpperCase().indexOf(tipo) > -1 ) {
            input.value = "0";
            input.disabled = true;
            input.nextElementSibling.innerHTML = "";
        }
    }
}

/**
 * Función que habilita el siguiente input de pedido nacional
 */
function habilitarSiguienteInputPed(tipo) {
    var i;
    var input;
    var inputs = $("input.text-box");
    for (i = 0; i < inputs.length; i++) {
        input = inputs[i];
        if (input.name.toUpperCase().indexOf(tipo) > -1 ) {
            if (input.value == 0 || input.disabled) {
                break;
            }
        }
    }
    if (i >= inputs.length)
        return;
    input = inputs[i];
    if (input.name.toUpperCase().indexOf(tipo) > -1 ) {
        input.value = "";
        input.disabled = false;
        input.focus();
    }
}

function validarParametros() {
    if ($("select#Temporada").val() == "") {
        MensajeWarning("No se ha seleccionado una temporada");
        return false;
    }
    else if ($("#contenedor div div").length <= 0) {
        MensajeWarning("No hay parámetros para actualizar");
        return false;
    }

    var inputs = $("input.text-box");
    var input;
    for (var i = 0; i < inputs.length; i++) {
        input = inputs[i];
        if (input.nextElementSibling.innerHTML != "") {
            MensajeError("Los datos ingresados son incorrectos");
            return false;
        }
    }
    if (sumaPorcentajePedidos(NACIONAL) != 100) {
        MensajeError("La suma de Porcentaje Nacional debe ser 100");
        return false;
    }
    if (sumaPorcentajePedidos(IMPORTADO) != 100) {
        MensajeError("La suma de Porcentaje Importado debe ser 100");
        return false;
    }
    MensajeInfo("Estamos guardando los parámetros");
    return true;

}

function actualizarParametros() {
    url = inicioUrl + "Inputs/UpdateParametros";
    $.ajax({
        type: "POST",
        url: url,
        data: { parametros: getParametros() },
        success: function (data) {
            MensajeSuccess("Parámetros actualizados");
        },
        error: function (e) {
            MensajeError("Error al actualizar los parametros");
        }
    });
    return false;
}

function getParametros() {
    var inputs = $("input.text-box");
    var shareObj = [];
    var input;
    for (var i = 0; i < inputs.length; i++) {
        input = inputs[i];
        item = {};
        item["idParam"] = input.id;
        item["paramCode"] = input.name;
        item["paramValue"] = input.value;
        item["season"] = season;
        shareObj.push(item);
    }
    return shareObj;
}

function agregarParametrosTemporada() {
    url = inicioUrl + "Inputs/AddParametrosTemporada";
    var temporada = $("#selTemporada").val();
    var anio = $("#selAño").val();
    data = {
        temporada: temporada,
        anio: anio
    }
    $.ajax({
        type: "POST",
        url: url,
        data: data,
        success: function (data) {
            season = temporada+anio;
            cargarTemporadas();
            $("div#ControladorTemporada").removeClass("open");
            $("div#ControladorTemporada div").attr("aria-expanded", "true");
            cambioTemporada(season);
        },
        error: function (e) {
            MensajeError(e.responseText);
        }
    });
    return false;
}