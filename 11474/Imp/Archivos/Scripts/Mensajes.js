
$(function () {
    toastr.options = {
        "closeButton": true,
        "debug": false,
        "newestOnTop": true,
        "progressBar": false,
        "positionClass": "toast-top-right",
        "preventDuplicates": true,
        "onclick": null,
        "showDuration": "10000",
        "hideDuration": "10000",
        "timeOut": "5000",
        "extendedTimeOut": "1000",
        "showEasing": "swing",
        "hideEasing": "linear",
        "showMethod": "fadeIn",
        "hideMethod": "fadeOut"
    }
});

function MensajeSuccess(mensaje) {
    toastr["success"](mensaje);
}

function MensajeError(mensaje) {
    toastr["error"](mensaje);
}

function MensajeInfo(mensaje) {
    toastr["info"](mensaje);
}

function MensajeWarning(mensaje) {
    toastr["warning"](mensaje);
}