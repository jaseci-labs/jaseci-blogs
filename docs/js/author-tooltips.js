// Add title attributes to author images for tooltips
document.addEventListener('DOMContentLoaded', function() {
    // Find all author images in blog previews
    const authorImages = document.querySelectorAll('.md-post__authors .md-author img');

    authorImages.forEach(img => {
        // If image has alt text but no title, copy alt to title
        if (img.alt && !img.title) {
            img.title = img.alt;
        }
    });
});