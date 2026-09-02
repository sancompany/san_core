// Autenticação real (Supabase Auth) ainda não está conectada.
// Este placeholder só evita o reload da página até a integração existir.
const loginForm = document.querySelector('#form-admin-login');

if (loginForm) {
  loginForm.addEventListener('submit', (e) => {
    e.preventDefault();
    alert('Login ainda não conectado ao Supabase Auth.');
  });
}
