// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
// import "@hotwired/turbo-rails";
// import "controllers";
//= require ahoy

// ahoy.configure({
//   visitsUrl: "/ah/visits",
//   eventsUrl: "/ah/events",
// })

$("#filter-search").on("click", () => {
  console.log("search");
  let q = $("#main-search").val() + ' '
  // let q = ''

  // $("input:checkbox:checked").each(function () {
  //   console.log(this.name);
  //   q += " or " + this.name + " ";
  // });

  $(".state-filter input:checkbox:checked").each(function () {
    console.log(this.name);
    q += "" + this.name + " ";
  });

  let sector = []
  $(".sector-filter input:checkbox:checked").each(function () {
    console.log(this.name);
    // q += "" + this.name + " ";
    sector.push(this.name)
  });

  if (sector.length > 0) {
    q += `(${sector.join(' or ')})`
  }

  let min_value = 0
  let max_value = 0

  const tender_filter = $("#tender-filter").val();
  const tender_value = $("#tender-value").val();
  let tender_value_amt = 0

  switch (tender_value) {
    case 'nil':
      tender_value_amt = 0
      break
    case '50l':
      tender_value_amt = 50 * 100000
      break
    case '1cr':
      tender_value_amt = 100 * 100000
      break
    case '5cr':
      tender_value_amt = 500 * 100000
      break
  }

  switch (tender_filter) {
    case 'lt':
      max_value = tender_value_amt
      break
    case 'gt':
      min_value = tender_value_amt
      max_value = 10 ** 10
  }

  const url = `${window.location.origin}/search?${$.param({
    q,
    min_value,
    max_value,
  })}`;
  window.location = url
//   console.log(url);
});

$('.state-filter input[type="checkbox"]').on('change', function () {
  $('.state-filter input[type="checkbox"]').not(this).prop('checked', false);
});

if ($('.tlt').length) {
  setTimeout(() => {
    $('.tlt').textillate({in: {effect: 'bounceIn'}});
  }, 2 * 1000);
}

$('#main-search-btn').on('click', (e) => {
  const query = $('#main-search').val()
  const userEmail = $('#user-email').text().trim()
  if (query.length) {
    ahoy.track("user_search", {
      query: query,
      url: window.location.href,
      time: new Date().toString(),
      email: userEmail.length > 0 ? userEmail : null
    });
  }
})
