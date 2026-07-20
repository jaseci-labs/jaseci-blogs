// Opt-in collapsible code blocks.
//
// Usage in markdown:
//   <div class="collapse" data-lines="5">
//
//   ```jac
//   ...code...
//   ```
//
//   </div>
//
// data-lines is optional (default 5). Only blocks longer than data-lines are collapsed.

(function () {
    const DEFAULT_LINES = 5;
    let counter = 0;

    function applyCollapse() {
        const wrappers = document.querySelectorAll('div.collapse');
        wrappers.forEach(function (wrapper) {
            if (wrapper.dataset.cbProcessed) return;
            wrapper.dataset.cbProcessed = '1';

            const block = wrapper.querySelector('.highlight, .highlighttable');
            if (!block) return;
            const pre = block.querySelector('pre');
            if (!pre) return;

            const text = pre.textContent || '';
            const totalLines = text.replace(/\n+$/, '').split('\n').length;
            const showLines = parseInt(wrapper.dataset.lines || DEFAULT_LINES, 10);

            if (totalLines <= showLines + 1) return; // already short enough

            // Compute max-height from the rendered line-height of the <pre>
            const cs = window.getComputedStyle(pre);
            const lh = parseFloat(cs.lineHeight) || 24;
            const padTop = parseFloat(cs.paddingTop) || 0;
            const padBottom = parseFloat(cs.paddingBottom) || 0;
            const maxH = (lh * showLines) + padTop + padBottom + 4;

            const id = 'cb-' + (counter++) + '-' + Math.random().toString(36).slice(2, 7);
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.id = id;
            checkbox.className = 'cb-toggle';

            const label = document.createElement('label');
            label.htmlFor = id;
            label.className = 'cb-label';
            label.setAttribute('data-lines', String(totalLines));

            wrapper.classList.add('cb-collapse');
            block.classList.add('cb-content');
            block.style.setProperty('--cb-max-height', maxH + 'px');

            wrapper.insertBefore(checkbox, block);
            wrapper.insertBefore(label, block);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', applyCollapse);
    } else {
        applyCollapse();
    }
})();
