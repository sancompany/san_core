const form = document.querySelector('#form-contato');
const confirmacao = document.querySelector('#contato-confirmacao');

if (form) {
  form.addEventListener('submit', (e) => {
    e.preventDefault();

    // Sem backend por enquanto: nada é salvo ou enviado.
    // Quando o e-mail/webmail da San & Co. estiver configurado,
    // este bloco passa a enviar os dados do formulário para lá.

    form.reset();
    form.setAttribute('hidden', '');
    if (confirmacao) confirmacao.classList.add('is-visible');
  });
}
