$(function() {
  
  console.log("application.js loaded");

  $("form.delete").submit(function(event) {
    event.preventDefault();
    event.stopPropagation();
    
    if (confirm("Are you sure you want to delete? This cannot be undone.")) {
      this.submit();
    }
  })

})