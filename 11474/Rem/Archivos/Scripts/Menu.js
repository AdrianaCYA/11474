$(function () {
    $("#menu-toggle").click(function (e) {
        e.preventDefault();
        $("#wrapper").toggleClass("active");
        $(".flotante").toggleClass("div-flotante");
    });
    toggleSubMenu();
});
function toggleSubMenu() {
    $(".treeview li>ul").css('display', 'none');
    $(".collapsible").click(function (e) {
        e.preventDefault();
        $(this).siblings("span").toggleClass("collapse expand");
        $(this).closest('li').children('ul').slideToggle();
    });
}