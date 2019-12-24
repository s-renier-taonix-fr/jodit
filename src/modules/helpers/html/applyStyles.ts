/*!
 * Jodit Editor (https://xdsoft.net/jodit/)
 * Licensed under GNU General Public License version 2 or later or a commercial license or MIT;
 * For GPL see LICENSE-GPL.txt in the project root for license information.
 * For MIT see LICENSE-MIT.txt in the project root for license information.
 * For commercial licenses see https://xdsoft.net/jodit/commercial/
 * Copyright (c) 2013-2019 Valeriy Chupurnov. All rights reserved. https://xdsoft.net
 */

import { Dom } from '../../Dom';
import { $$ } from '../selector';

function normalizeCSS(s: string) {
	return s.replace(/mso-[a-z\-]+:[\s]*[^;]+;/gi, '')
		.replace(/mso-[a-z\-]+:[\s]*[^";]+$/gi, '')
		.replace(/border[a-z\-]*:[\s]*[^;]+;/gi, '')
		.replace(/([0-9.]+)pt/gi, match => {
			return (
				(parseFloat(match) * 1.328).toFixed(0) +
				'px'
			);
		})
}

export const applyStyles = (html: string): string => {
	if (html.indexOf('<html ') === -1) {
		return html;
	}

	html = html.substring(html.indexOf('<html '), html.length);
	html = html.substring(0, html.lastIndexOf('</html>') + '</html>'.length);

	const iframe = document.createElement('iframe');

	iframe.style.display = 'none';
	document.body.appendChild(iframe);

	let convertedString: string = '',
		collection: HTMLElement[] = [],
		rules: CSSStyleRule[] = [];

	try {
		const iframeDoc: Document | null =
			iframe.contentDocument ||
			(iframe.contentWindow ? iframe.contentWindow.document : null);

		if (iframeDoc) {
			iframeDoc.open();
			iframeDoc.write(html);
			iframeDoc.close();

			if (iframeDoc.styleSheets.length) {
				rules = (iframeDoc.styleSheets[
					iframeDoc.styleSheets.length - 1
				] as any).cssRules;
			}

			for (let idx = 0; idx < rules.length; idx += 1) {
				if (rules[idx].selectorText === '') {
					continue;
				}

				collection = $$(rules[idx].selectorText, iframeDoc.body);

				collection.forEach((elm: HTMLElement) => {
					elm.style.cssText = normalizeCSS(rules[idx].style.cssText + ';' + elm.style.cssText);
				});
			}

			Dom.each(iframeDoc.body, (node) => {
				if (node?.nodeType === Node.ELEMENT_NODE) {
					const elm = node as HTMLElement;
					const css = elm.style?.cssText;
					console.log(css);

					if (css) {
						elm.style.cssText = normalizeCSS(css);
					}

					if (elm.hasAttribute('lang')) {
						elm.removeAttribute('lang');
					}
				}
			});

			convertedString = iframeDoc.firstChild
				? iframeDoc.body.innerHTML
				: '';
		}
	} catch {
	} finally {
		Dom.safeRemove(iframe);
	}

	if (convertedString) {
		html = convertedString;
	}

	return html
		.replace(/<(\/)?(html|colgroup|col|o:p)[^>]*>/g, '')
		.replace(/<!--[^>]*>/g, '');
};
