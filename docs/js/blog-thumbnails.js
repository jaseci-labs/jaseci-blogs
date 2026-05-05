// Blog post thumbnails - Medium-style image previews

document.addEventListener('DOMContentLoaded', function() {
  // Wait for blog posts to load
  setTimeout(addBlogThumbnails, 500);
});

function addBlogThumbnails() {
  // Find blog posts using the actual class names
  const blogPosts = document.querySelectorAll('article.md-post');

  // Enhanced image mappings - match by title, URL, and content
  const imageMap = {
    'nairobi': '/assets/nairobi-ai-jaseci-ouk-1.jpg',
    'protomcp': '/assets/mcp-protolab/landing-page.png',
    'postman': '/assets/mcp-protolab/landing-page.png',
    'mcp': '/assets/mcp-protolab/landing-page.png',
    'meta-packages': '/assets/jaseci_labs_logo.PNG',
    'meta': '/assets/jaseci_labs_logo.PNG',
    'packages': '/assets/jaseci_labs_logo.PNG',
    'four-things': '/assets/jaseci_labs_logo.jpg',
    'four things': '/assets/jaseci_labs_logo.jpg',
    'object-spatial': '/assets/jaseci_labs_logo.jpg',
    'browser-automation': '/assets/jaseci_labs_logo.PNG',
    'walkers': '/assets/jaseci_labs_logo.PNG',
    'dataclasses': '/assets/jaseci_labs_logo.jpg',
    'python': '/assets/jaseci_labs_logo.jpg',
    'jac-vs-sota': '/assets/jaseci_labs_logo.PNG',
    'same app': '/assets/jaseci_labs_logo.PNG',
    'polyglot': '/assets/jaseci_labs_logo.PNG',
    'todo': '/assets/jaseci_labs_logo.PNG',
    'jacd': '/assets/jaseci_labs_logo.jpg',
    'making-jac': '/assets/jaseci_labs_logo.PNG',
    'traversals': '/assets/jaseci_labs_logo.PNG',
    'faster': '/assets/jaseci_labs_logo.PNG',
    'socratic': '/assets/jaseci_labs_logo.jpg',
    'prompt': '/assets/jaseci_labs_logo.jpg'
  };

  blogPosts.forEach((post, index) => {
    // Skip if already processed
    if (post.classList.contains('thumbnail-added')) {
      return;
    }

    // Try multiple selectors to find the title
    const titleElement = post.querySelector('.md-post__title') ||
                         post.querySelector('h2') ||
                         post.querySelector('h3') ||
                         post.querySelector('a[aria-label]');

    const linkElement = post.querySelector('a');

    // Get title from different sources
    let title = '';
    if (titleElement) {
      title = titleElement.textContent.toLowerCase().trim();
    }
    const postUrl = linkElement ? linkElement.getAttribute('href') : '';
    const linkText = linkElement ? linkElement.textContent.toLowerCase().trim() : '';

    // Determine which image to use based on title, link text, or URL
    let imageUrl = '/assets/jaseci_labs_logo.jpg'; // Default image

    for (const [key, image] of Object.entries(imageMap)) {
      if (title.includes(key) || linkText.includes(key) || postUrl.includes(key)) {
        imageUrl = image;
        break;
      }
    }

    addThumbnailToPost(post, imageUrl);
  });
}

function addThumbnailToPost(post, imageUrl) {
  // Find the title element
  const titleElement = post.querySelector('.md-post__title') ||
                       post.querySelector('h2') ||
                       post.querySelector('h1');

  // Create thumbnail container
  const thumbnail = document.createElement('div');
  thumbnail.className = 'md-post__thumbnail';
  thumbnail.style.cssText = `
    width: 25%;
    flex-shrink: 0;
    height: 120px;
    overflow: hidden;
    border-radius: 8px;
  `;

  const img = document.createElement('img');
  img.src = imageUrl;
  img.alt = 'Blog post thumbnail';
  img.style.cssText = `
    width: 100%;
    height: 100%;
    object-fit: cover;
  `;
  thumbnail.appendChild(img);

  // Create a flex container for title + thumbnail
  const headerContainer = document.createElement('div');
  headerContainer.className = 'md-post__header-container';
  headerContainer.style.cssText = `
    display: flex;
    gap: 5%;
    align-items: flex-start;
    margin-bottom: var(--space-4);
    width: 100%;
  `;

  // Create title container (70% width)
  const titleContainer = document.createElement('div');
  titleContainer.className = 'md-post__title-container';
  titleContainer.style.cssText = `
    width: 70%;
    flex-shrink: 0;
  `;

  // Add the title class to the element and move it to the title container
  titleElement.classList.add('md-post__title');
  titleContainer.appendChild(titleElement);

  // Add title container and thumbnail to header
  headerContainer.appendChild(titleContainer);
  headerContainer.appendChild(thumbnail);

  // Insert the header container at the beginning of the post
  post.insertBefore(headerContainer, post.firstChild);

  // Mark as processed
  post.classList.add('thumbnail-added');
}
