// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
// import "@hotwired/turbo-rails";
// import "controllers";

console.log("a");

$("#filter-search").on("click", () => {
  console.log("search");
  let q = "";

  $("input:checkbox:checked").each(function () {
    console.log(this.name);
    q += this.name + " ";
  });

  const min_value = $("#tender-value-min").val();
  const max_value = $("#tender-value-max").val();

  const url = `${window.location.origin}/search/?${$.param({
    q,
    min_value,
    max_value,
  })}`;
  window.location = url
//   console.log(url);
});

setTimeout(() => {
    $('.tlt').textillate({ in: { effect: 'bounceIn' } });
}, 2*1000);
