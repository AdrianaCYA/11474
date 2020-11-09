var columEdit = false;
var columDelete = false;
var permissionExport = false;

$(function () {
    cargarTipoTalla();
    $("#Division").change(function () {
        limpiarSelects("Division");
        $("#Division option:selected").each(function () {
             //cargarSubDivision($("#Division option:selected").text());
        });
    });    
    $("#SubDivision").change(function () {
        limpiarSelects("SubDivision");
        $("#SubDivision option:selected").each(function () {
            cargarGrupo(
                $("#Division option:selected").text(),
                $("#SubDivision option:selected").text()
            );
        });
    });
    $("#Grupo").change(function () {
        limpiarSelects("Grupo");
        $("#Grupo option:selected").each(function () {
            cargarFamilia(
                $("#Division option:selected").text(),
                $("#SubDivision option:selected").text(),
                $("#Grupo option:selected").text()
            );
        });
    });
    $("#Familia").change(function () {
        limpiarSelects("Familia");
        $("#Familia option:selected").each(function () {
            cargarSubFamilia(
                $("#Division option:selected").text(),
                $("#SubDivision option:selected").text(),
                $("#Grupo option:selected").text(),
                $("#Familia option:selected").text()
            );
        });
    });
    $("#PackA").change(function () {
        Validador.validarMayorCero(this);
    });
    $("#GuardarPackA").click(function () {
        if (!Validador.validarMayorCero(document.getElementById("PackA")) || estanVaciosSelect()) {
            MensajeError("Faltan datos por ingresar");
            return false;
        }
        guardarDatos();
    });

    $("select#TipoTalla").change(function () {
        MVCGrid.setParamDistinct('PackAGrid', "TipoTalla", $('select#TipoTalla option:selected').text());
    })
    
    $('#selTamanioPaginas').change(function () {
        MVCGrid.setPageSize('PackAGrid', $('#selTamanioPaginas').val());
    });
    // set value of dropdown to grid setting
    $('#selTamanioPaginas').val(MVCGrid.getPageSize('PackAGrid'));

    $("#cargarFile").change(function () {
        document.getElementById('textoFile').innerHTML = this.files[0].name;
    });

    $("#btnSubir").click(function () {
        subirArchivo();
    });

    $('#Exportar').click(function () {
        if (!permissionExport) {
            MensajeError("No tiene permisos para exportar");
            return;
        }
        MensajeInfo("Exportando datos");
        removeColums();
        location.href = MVCGrid.getExportUrl('PackAGrid');
        setColumGridPermission();
    });

    $("select#TipoTalla").change(function () {
        MVCGrid.setParamDistinct('PackAGrid', "TipoTalla", $('select#TipoTalla option:selected').text());
    })

    $("button#confirmDelete").click(function () {
        deletePackA($("button#confirmDelete").val());
        $("div#modalConfrim").modal("hide");
    });
    filtros();
    setColumGridPermission();
});

/* Permission for edit and remove */
function setPermission(edit, remove, exportP) {
    columEdit = (edit == 'True');
    columDelete = (remove == 'True');
    permissionExport = (exportP == 'True');
    setColumGridPermission();
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
    $("select#TipoTalla").change(function () {
        consultar();
    });
}
function consultar() {
    $("#Filtro").removeClass("open");
    $("#FiltroBoton").attr("aria-expanded", false);
    MVCGrid.setFiltersButton("PackAGrid");
}

/* Editar tamaño pack A */
function editarPackA(id) {
    var elemento = $("button#btn" + id).parents("tr").children().eq(6);
    var valor = elemento.text();
    var input = "<input type='text' class='form-control tamEdit' value='" + valor + "' id='" + id + "' />";
    elemento.text("");
    elemento.append(input);
    $("button#btn" + id).addClass("hide");
    if ($("button#save").length == 0) {
        var save = "<button type = 'button' class='btnEdit' id='save'></button>"
        $("thead").children().children().eq(7).append(save);
        save = "<span class='glyphicon glyphicon-floppy-saved' ></span >";
        $("thead").children().children().eq(7).children().eq(0).append(save);
        $("button#save").click(function () {
            guardarPackA();
        });
    }

}

function guardarPackA() {
    //validamos los datos
    var correct = 1;
    $("tr").find("input").each(function () {
        if (!Validador.validarDatos(this)) 
            correct = 0;
    });
    if (correct == 0) {
        MensajeError("Error en los datos");
        return false;
    }

    // obtenemos valores a actualizar
    var obj = [];
    $("tr").find("input").each(function () {
        item = {};
        item["id"] = this.id;
        item["value"] = this.value;
        obj.push(item);        
    });
    var url = inicioUrl + "Packa/GuardarPackA";
    var datos = { values: obj };

    MensajeInfo("Actualizando los datos");

    //enviamos los datos al controllador
    $.ajax({
        type: "POST",
        url: url,
        data: datos,
        success: function (data) {
            $("thead").children().children().eq(7).children().remove();
            MVCGrid.reloadGrid("PackAGrid");
            MensajeSuccess("Datos actualizados");
        },
        error: function (e) {
            MensajeError("Error al actualizar los datos");
            MVCGrid.reloadGrid("PackAGrid");
        }
    });
    return false;
}
function cargarTipoTalla() {
    url = inicioUrl + "Packa/ConsultarTipoTalla";
    var datos = {
    };
    cargarDatos(datos, url, "TipoTalla");
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
        }
    });
    return false;
}

function subirArchivo() {
    if ($("#cargarFile")[0].files.length == 0) {
        MensajeWarning("Seleccione un archivo");
        return null;
    }
    MensajeInfo("Estamos guardando los datos");
    var file = $("#cargarFile")[0].files[0];
    var data = new FormData();
    data.append("file", file);
    var url = inicioUrl + "Packa/CargarArchivo";
    $.ajax({
        type: 'POST',
        url: url,
        data: data,
        contentType: false,
        processData: false,
        success: function (data) {
            MVCGrid.reloadGrid("PackAGrid");
            MensajeSuccess("Datos importados correctamente");
            $("#cargarFile").val("");
            document.getElementById('textoFile').innerHTML = "Cargar Archivo";
        },
        error: function (e) {
            MensajeError(e.responseText);
        }
    });
    return false;
}

function llenarSelect(nombreSelect, arreglo) {
    $("#" + nombreSelect + " option").remove();
    $("#" + nombreSelect).append("<option value=''></option>");
    $.each(arreglo, function (key, value) {
        $("#" + nombreSelect).append("<option value=" + value + ">" + value + "</option>");
    });
}

function limpiarSelects(campo) {
    if (campo == "Familia")
        $("#SubFamilia option").remove();
    else if (campo == "Grupo") {
        $("#SubFamilia option").remove();
        $("#Familia option").remove();
    }
    else if (campo == "SubDivision") {
        $("#SubFamilia option").remove();
        $("#Familia option").remove();
        $("#Grupo option").remove();
    }
    else if (campo == "Division") {
        $("#SubFamilia option").remove();
        $("#Familia option").remove();
        $("#Grupo option").remove();
        $("#SubDivision option").remove();
    }
}

function estanVaciosSelect() {
    if ($("#Division option:selected").text() == "" || $("#SubDivision option:selected").text() == "" ||
        $("#Grupo option:selected").text() == "" || $("#Familia option:selected").text() == "" ||
        $("#SubFamilia option:selected").text() == "")
        return true;
    return false;
}
/**
 * Confirmar la eliminación tamaño pack a
 * @param {int} id
 */
function confirmDelete(id) {
    $("button#confirmDelete").val(id);
    $("div#modalConfrim").modal("show");
}
/**
 * Borrar tamaño de pack a incluyendo estructura comercial
 * @param {int} id
 */
function deletePackA(id) {
    var url = inicioUrl + "Packa/DeletePackA";
    MensajeInfo("Eliminando Tamaño de Pack A");
    //enviamos los datos al controllador
    $.ajax({
        type: "POST",
        url: url,
        data: { id: id },
        success: function (data) {
            MVCGrid.reloadGrid("PackAGrid");
            MensajeSuccess("Datos actualizados");
        },
        error: function (e) {
            MVCGrid.reloadGrid("PackAGrid");
            MensajeError("Error al actualizar los datos");
        }
    });
    return false;
}
/**
 * Remove columns edit and delete of grid 
 */
function removeColums() {
    MVCGrid.setColumnVisibility('PackAGrid', { "Edit": false });
    MVCGrid.setColumnVisibility('PackAGrid', { "Delete": false });
}
/**
 * Remove column edit of grid 
 */
function setColumGridPermission() {
    MVCGrid.setColumnVisibility('PackAGrid',
        {
            "Division": true,
            "SubDivision": true,
            "Grupo": true,
            "Familia": true,
            "Subfamilia": true,
            "TipoTalla": true,
            "PackA": true,
            "Edit": columEdit,
            "Delete": columDelete
        });
}