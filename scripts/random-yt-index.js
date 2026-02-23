const videos = [
    "zLzTvn4U014", /* LLS Marisa Theme */
    "jKOsjHOzEJo", /* TKM Extra Theme: Alice in Wonderland ~Remix */
    "aE8TV7ZqAHU", /* In Memory of Friends */
    "N-cU-M_tX68", /* Jesus Loves Junkies - Escape From Paradise */
    "9OJhV_z3mKE", /* Touhou MMD - Romance no Kamisama */
    "KCgr3dj5mqY", /* Round Table - Puzzle */
    "k7bIKXekryw", /* Viper - I Been Listening To Pururin For Da Past 10 Hours */
    "o2wrqT1ZMxY", /* Double Dragon 2 Cover */
    "kAw7w1AOwS8", /* Mastodon - Blood and Thunder Live */
    "JimUMZTiAjo", /* Monzy - So much drama in the PhD */
    "LCS0kq5ynDg", /* Afia Oil 10 Hours */
    "nno4Z-w6PMY", /* Back To The Gate */
    "An_h_uLHMNo", /* Opeth - To Bid You Farewell */
    "dbALGHsue_A", /* Heartbreak Mermaid Yakuza 0 edit */
    "KxPZWQ1wPUg", /* RDB - Aja Mahi */
    "eGrg6JHlByw", /* Jerma Owes the Precious 2.5 Billion Dollars */
    "2aK4NuHWDQc", /* Kanako Ito - Fake me (samfree remix) */
    "Oh4vrw5vA7Q", /* Alien Gods - Animal Party */
    "-mh0vism1c4", /* 18 Nightcore */
    "AODD6vPbNFk", /* Umapyoi Densetsu */
    "53q_LD8ls-Y", /* Uma Musume - God, Syria and HELIOS! */
    "4gLB8vxfD_c" /* Tasukete Lenin */
];

const intro = document.getElementById("intro");

function init() {
    if (!intro) return;

    /* text */
    const text = document.createElement("p");
    text.textContent = "click on me for some cool stuff";
    text.style.cursor = "pointer";
    text.style.color = "var(--yellow)";
    text.addEventListener("click", () => {
        insert();
        text.remove();
    });

    intro.insertAdjacentElement("afterend", text);
}

function insert() {
    if (!intro) return;

    /* iframe */
    const video = videos[Math.floor(Math.random() * videos.length)];
    const iframe = document.createElement("iframe");

    iframe.src = "https://www.youtube.com/embed/" + video;
    iframe.frameBorder = "0";
    iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share";
    iframe.referrerPolicy = "strict-origin-when-cross-origin";
    iframe.allowFullscreen = true;
    iframe.style.width = "100%";

    /* hint */
    const hint = document.createElement("span");
    hint.textContent = "hint: click here for another video";
    hint.className = "video-hint";
    hint.style.fontSize = "smaller";
    hint.style.opacity = "0.7";
    hint.style.cursor = "pointer";
    hint.addEventListener("click", () => {
        const video = videos[Math.floor(Math.random() * videos.length)];
        iframe.src = "https://www.youtube.com/embed/" + video;
    });

    /* iframe parent */
    const iframeParent = document.createElement("div");
    iframeParent.className = "iframe-parent";
    iframeParent.appendChild(iframe);

    /* insert after intro */
    intro.insertAdjacentElement("afterend", iframeParent);
    intro.insertAdjacentElement("afterend", hint);
}

init();
