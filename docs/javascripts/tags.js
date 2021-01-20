document.body.innerHTML = document.body.innerHTML.replace(/{read-only}/g, '<p class="tag read-only">read-only</p>');
document.body.innerHTML = document.body.innerHTML.replace(/{static}/g, '<p class="tag static">static</p>');
document.body.innerHTML = document.body.innerHTML.replace(/{server-only}/g, '<p class="tag server-only">server-only</p>');
document.body.innerHTML = document.body.innerHTML.replace(/{client-only}/g, '<p class="tag client-only">client-only</p>');
document.body.innerHTML = document.body.innerHTML.replace(/{deprecated}/g, '<p class="tag deprecated">deprecated</p>');

function cleaner(el) {
  if (el.innerHTML === '&nbsp;' || el.innerHTML === '') {
    el.parentNode.removeChild(el);
  }
}

const elements = document.querySelectorAll('p');
elements.forEach(cleaner);