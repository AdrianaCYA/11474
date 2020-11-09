/* Inicio de la URL del sistema */
var inicioUrl = "";
/**
 * Establecemos la ruta inicial del sistema
 * @param {any} url
 */
function setInicioUrl(url) {
    inicioUrl = url;
}


function cerrarSesion() {
    url = inicioUrl + "Account/LogoutSession";
    $.ajax({
        type: "POST",
        url: url,
        success: function (data) {
            location.reload();
        },
        error: function (e) {
        }
    });
}