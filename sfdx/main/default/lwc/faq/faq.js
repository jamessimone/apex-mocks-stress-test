import { LightningElement, wire } from 'lwc';
import getFAQs from '@salesforce/apex/FAQController.getFAQs';

export default class FAQList extends LightningElement {
    @wire(getFAQs) faqs;

    handleClick(event) {
        event.preventDefault();
        const foundEl = this.faqs.data.filter(
            el => el.question === event.target.innerHTML
        );
        if (foundEl.length > 0) {
            foundEl[0].isExpanded = !foundEl[0].isExpanded;
        }
    }
}
