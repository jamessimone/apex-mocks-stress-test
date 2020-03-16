import { createElement } from 'lwc';
import { registerApexTestWireAdapter } from '@salesforce/sfdx-lwc-jest';

import FAQ from 'c/faq';
import getFAQs from '@salesforce/apex/FAQController.getFAQs';

const listCount = 1000;

const getFakeFAQs = () => {
    const faqs = [];
    for (let index = 0; index < listCount; index++) {
        faqs.push({
            question: 'test question' + index,
            answer: 'test answer ' + index,
            isExpanded: false,
            key: index
        });
    }
    return faqs;
};

const getFAQAdapter = registerApexTestWireAdapter(getFAQs);

function assertForTestConditions() {
    const resolvedPromise = Promise.resolve();
    return resolvedPromise.then.apply(resolvedPromise, arguments);
}

describe('FAQ', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    describe('FAQ tests', () => {
        it('renders full faq list', () => {
            const element = createElement('faq-list', {
                is: FAQ
            });

            document.body.appendChild(element);
            getFAQAdapter.emit(getFakeFAQs());

            return assertForTestConditions(() => {
                expect(element.shadowRoot.querySelectorAll('a').length).toBe(
                    listCount
                );
            });
        });

        it('expands and contracts on click', () => {
            const element = createElement('faq-list', {
                is: FAQ
            });
            document.body.appendChild(element);
            getFAQAdapter.emit(getFakeFAQs());

            //get the first anchor and test clicking it
            assertForTestConditions(
                () => element.shadowRoot.querySelector('a').click(),
                () =>
                    expect(
                        element.shadowRoot.querySelectorAll('p').length
                    ).toBe(1)
            );
        });
    });
});
