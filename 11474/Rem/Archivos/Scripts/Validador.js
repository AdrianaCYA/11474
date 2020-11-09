var Validador = new function () {

    /* Mensajes al usuario */
    const CAMPO_OBLIGATORIO = "Campo obligatorio";
    const SOLO_NUMEROS = "Solo se aceptan números";
    const FUERA_RANGO = "El valor está fuera de rango (0-100)";
    const NUMERO_POSITIVO = "El número debe ser positivo";
    const NUMERO_MAYOR_CERO = "El número deber ser mayor a 0";


    this.init = function () { }


    /**
     * Función que verifica que lo ingresado por el usuairo este correcto
     * @param {input} input
     * @return {bool}
     */
    this.validarDatos = function (input) {
        // Verifica si el valor es vacio
        if (estaVacio(input.value)) {
            if (input.nextElementSibling != null)
                input.nextElementSibling.innerHTML = CAMPO_OBLIGATORIO;
            tieneError(input);
            return false;
        }
        // Verifica si el valor ingresado es un número
        if (!esNumero(input.value)) {
            if (input.nextElementSibling != null)
                input.nextElementSibling.innerHTML = SOLO_NUMEROS;
            tieneError(input);
            return false;
        }
        // Verifica si el valor ingresado es un número positivo
        if (!esPositivo(input.value)) {
            if (input.nextElementSibling != null)
                input.nextElementSibling.innerHTML = NUMERO_POSITIVO;
            tieneError(input);
            return false;
        }
        if (input.nextElementSibling != null)
            input.nextElementSibling.innerHTML = "";
        tieneExito(input);
        return true;
    }

    /**
     * Función que verifica que lo ingresado por el usuairo este correcto
     * @param {input} input
     * @return {bool}
     */
    this.validarShare = function (input) {
        var str = /^[0-9]{1,3}(.[0-9]{1,6})?$/g;

   
        var result = input.value.match(str);
        if (result == null || result <= 0 || result > 100) {
            tieneError(input);
            return false;
        }        
        tieneExito(input);
        return true;
    }

    /**
     * Función indica si es error o no
     * @param {input} input
     * @return      */
    this.Error = function (input) {
        tieneError(input);
    }

    /**
     * Función indica si es error o no
     * @param {input} input
     * @return      */
    this.Exito = function (input) {
        tieneExito(input);
    }

    /**
     * Validamos que los datos sean mayor a cero
     * @param {any} input
     */
    this.validarMayorCero = function (input) {
        if (!Validador.validarDatos(input))
            return false;
        if (!esMayorCero(input.value)) {
            if (input.nextElementSibling != null)
                input.nextElementSibling.innerHTML = NUMERO_MAYOR_CERO;
            tieneError(input);
            return false;
        }
        if (input.nextElementSibling != null)
            input.nextElementSibling.innerHTML = "";
        tieneExito(input);
        return true;
    }

    /**
     * Validamos los datos que son de tipo porcentaje
     * @param {any} input
     */
    this.validarDatosPorcentaje = function (input) {
        if (!Validador.validarDatos(input))
            return false;

        // Verifica que el valor ingresado este dentro del rango de porcentaje
        if (!esPorcentajeValido(input.value)) {
            if (input.nextElementSibling != null)
                input.nextElementSibling.innerHTML = FUERA_RANGO;
            tieneError(input);
            return false;
        }
        if (input.nextElementSibling != null)
            input.nextElementSibling.innerHTML = "";
        tieneExito(input);
        return true;
    }

    /**
     * Funcion para validar si se ingresaron solo números
     * @param {string} valor
     * @return {boolean}
     */
    function esNumero(valor) {
        return !isNaN(valor);
    }

    /**
     * Funcion para validar que este dentro del rango
     * @param {int} valor
     * @return {booblean}
     */
    function esPorcentajeValido(valor) {
        return (valor >= 0 && valor <= 100);
    }

    /**
     * Determina si un valor es positivo 
     * @param {any} valor
     * @return {bool}
     */
    function esPositivo(valor) {
        return (valor >= 0);
    }

    /**
     * Funcion para comprobar si el valor esta vacio
     * @param {string} valor
     * @return {bool}
     */
    function estaVacio(valor) {
        return (valor == "");
    }

    /**
     * Funcion para determinar si un número es mayor a cero
     * @param {any} valor
     * @return {bool}
     */
    function esMayorCero(valor) {
        return (valor > 0);
    }


    /**
     * Funcion que pone color al contorno del input cuando tiene exito
     * @param {any} input
     */
    function tieneExito(input) {
        $("#" + input.id).parent().addClass("has-success");
        $("#" + input.id).parent().removeClass("has-error");
    }

    /**
     * Funcion que pone color al contorno del input cuando tiene error
     * @param {any} input
     */
    function tieneError(input) {
        $("#"+input.id).parent().addClass("has-error");
        $("#" + input.id).parent().removeClass("has-success");
    }

}