var editPermission = false;

$(function () {
    //cleanDataModals();
    //showProcess();
    getPerfiles();
    $("div#allData").hide();

    // page size
    $("select#selTamanioPaginas").change(function () {
        MVCGrid.setPageSize("ActivitiesGrid", $("select#selTamanioPaginas").val());
    });
    // change perfil
    $("select#profiles").change(function () {
        switchProfiles();
    });
});

/**
 * Show/Hide Colum Delete from Grid
 * @param {string} haveP
 */
function setEditPermissions(havep) {
    (havep == "False") ? editPermission = false : editPermission = true;
}
/**
 * Get Permission per profile
 * @param {any} opc
 * @param {any} profile
 * @param {any} activities
 */
function getPermissionProfile(opc, profile, activities) {
    var url = inicioUrl + "Config/GetPermissionProfile";
    $.ajax({
        type: "POST",
        url: url,
        data: {
            profile: profile,
            activities: activities
        },
        success: function (data) {
            changeColumnPermission(opc, data);
        },
        error: function (e) {
            MensajeError(e.responseText);
        }
    });
}
/**
 * Get Pefiles
 */
function getPerfiles() {
    var url = inicioUrl + "Config/GetPerfiles";
    $.ajax({
        type: "POST",
        url: url,
        success: function (data) {
            fillInProfiles(data);
        },
        error: function (e) {
            MensajeError(e.responseText);
            //hideProcess();
        }
    });
}
/**
 * Set Permission per profile
 * @param {any} opc
 * @param {any} profile
 * @param {any} activities
 */
function setPermissionProfile(opc, profile, activities, permissions) {
    var url = inicioUrl + "Config/SetPermissionProfile";
    $.ajax({
        type: "POST",
        url: url,
        data: {
            profile: profile,
            activities: activities,
            permissions: permissions
        },
        success: function (data) {
            getPermissionProfile(opc, profile, activities);
        },
        error: function (e) {
            MensajeError(e.responseText);
        }
    });
}
/**
 * Fill in perfiles select
 * @param {any} perfiles
 */
function fillInProfiles(profiles) {
    $("select#profiles option").remove();
    $("select#profiles").append("<option value=''>Seleccione un perfil</option>");
    $.each(profiles, function (key, value) {
        $("select#profiles").append("<option value='" + value.profile + "'>" + value.profile + "</option>");
    });
    //hideProcess();
}
/**
 * Switch profile
 */
function switchProfiles() {
    if ($("select#profiles").val() == '') {
        $("div#allData").hide();
        return;
    }
    $("div#allData").show();
    MVCGrid.setAdditionalQueryOptions('ActivitiesGrid',
        { "profile": $('select#profiles option:selected').val() });

}
/*
 * Edit or save activities per profile
 */
function editSaveActivity() {
    //showProcess();
    if (!editPermission)
        MensajeError("No tiene permisos para editar");
    var profile = $("select#profiles").val();
    var list;
    switch ($("button#editSave").val()) {
        case "0":
            getPermissionProfile(1, profile, getActivitiesView());
            break;
        case "1":
            setPermissionProfile(0, profile, getActivitiesView(), getPermissionsView());
            break;
    }
}
/**
 * Change view column permission
 * @param {int} opc
 * @param {list} list
 */
function changeColumnPermission(opc, list) {
    changeButton(opc);
    var data = $("tbody > tr");
    $.each(data, function (index, element) {
        var id = element.children[0].innerText;
        var obj = searchList(list, id);
        var column = element.children[2];
        column.removeChild(column.children[0])
        changeColumn(opc, column, obj);
    })
    //hideProcess();
}
/**
 * 
 * @param {int} opc
 */
function changeButton(opc) {
    switch (opc) {
        case 1:
            $("button#editSave").val(opc);
            $("button#editSave > i").removeClass("fas fa-pencil-alt");
            $("button#editSave > i").addClass("fas fa-save");
            break;
        case 0:
            $("button#editSave").val(opc);
            $("button#editSave > i").removeClass("fas fa-save");
            $("button#editSave > i").addClass("fas fa-pencil-alt");
            break;
    }
}
/**
 * Change column
 * @param {int} opc
 * @param {html} element
 * @param {object} obj
 */
function changeColumn(opc, element, obj) {
    var textElement = "";
    var child, parent;
    switch (opc) {
        case 0:
            child = document.createElement("i");
            child.className = (obj.EXIST.toUpperCase() == 'S') ? "fas fa-check" : "fas fa-times";
            element.appendChild(child);
            break;
        case 1:
            parent = document.createElement("label");
            parent.className = "container";
            child = document.createElement("input");
            child.type = "checkbox";
            child.id = obj.id;
            if (obj.EXIST.toUpperCase() == 'S')
                child.checked = true;
            parent.appendChild(child);
            child = document.createElement("span");
            child.className = "checkmark";
            parent.appendChild(child);
            element.appendChild(parent);
            break;
    }
}
/**
 * Get Activities in the view
 */
function getActivitiesView() {
    var data = $("tbody > tr");
    var list = [];
    $.each(data, function (index, element) {
        list.push(element.children[0].innerText);
    })
    return list;
}
/**
 * Search number in list
 * @param {list} list
 * @param {int} number
 */
function searchList(list, number) {
    var objReturn;
    $(list).each(function (index, obj) {
        if (obj.id == number)
            objReturn = obj;
    })
    return objReturn;
}
/**
 * Get Permissions of view
 */
function getPermissionsView() {
    var data = $("tbody > tr");
    var list = [];
    $.each(data, function (index, element) {
        if (element.children[2].children[0].children[0].checked)
            list.push(element.children[0].innerText);
    })
    return list;
}