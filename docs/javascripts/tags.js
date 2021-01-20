const style = `.tag {
	color: #ffffff;
	line-height: .8rem;
	padding: 5px;
	margin-left: 10px !important;
	margin: 0;
	background-clip: padding-box;
	border-radius: 5px;
	display: inline-block;
	font-size: .7rem;
}
.read-only {
	background-color: rgb(12, 95, 78);
}

.static {
	background-color: rgb(230, 126, 34);
}

.server-only {
	background-color: rgb(52, 155, 235);
}

.client-only {
	background-color: rgb(162, 52, 235);
}

.deprecated {
	background-color: rgb(255, 0, 0);
}

.chainable {
	background-color: rgb(255, 0, 0);
}

h4 {
	display: inline;
}`

var inner = document.body.innerHTML
inner = inner.replace(/{read-only}/g, '<p class="tag read-only">read-only</p>');
inner = inner.replace(/{static}/g, '<p class="tag static">static</p>');
inner = inner.replace(/{server-only}/g, '<p class="tag server-only">server-only</p>');
inner = inner.replace(/{client-only}/g, '<p class="tag client-only">client-only</p>');
inner = inner.replace(/{deprecated}/g, '<p class="tag deprecated">deprecated</p>');
document.body.innerHTML = inner

const styleElement = document.createElement("style")
styleElement.innerHTML = style

document.head.appendChild(styleElement)

function cleaner(el) {
	if (el.innerHTML === '&nbsp;' || el.innerHTML === '') {
		el.parentNode.removeChild(el);
	}
}

const elements = document.querySelectorAll('p');
elements.forEach(cleaner);