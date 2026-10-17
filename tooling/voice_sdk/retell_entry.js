import { RetellWebClient } from 'retell-client-js-sdk';
import { createRetellBridge } from './bridge.js';
window.skillSenseRetell = Object.freeze({create: callback => createRetellBridge(RetellWebClient, callback)});
