const form = document.getElementById('login');

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  const [email, password] = form.querySelectorAll('input');
  const res = await fetch('/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: email.value, password: password.value }),
  });
  const data = await res.json();
  localStorage.setItem('token', data.token);
  window.location = '/dashboard.html';
});

function openSignup() {
  document.querySelector('.hero').innerHTML = '<h1>Welcome, ' + new URLSearchParams(location.search).get('name') + '</h1>';
}
