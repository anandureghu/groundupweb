export function ThemeScript() {
  const code = `(function(){try{var t=localStorage.getItem("theme");if(t==="dark"||(!t&&window.matchMedia("(prefers-color-scheme: dark)").matches)){document.documentElement.classList.add("dark")}}catch(e){}})();`;

  return <script dangerouslySetInnerHTML={{ __html: code }} />;
}
