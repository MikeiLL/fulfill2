import { choc, on, DOM } from "https://rosuav.github.io/choc/factory.js";
const {H1} = choc; //autoimport
import * as utils from "./utils.js";

export function render(state) {
  set_content("#indexbox", [
    H1(state.hello),
    H1(state.hello),
    H1(state.hello),
    H1(state.hello),
    H1(state.hello),
  ]);
}
