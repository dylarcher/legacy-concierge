// legacyConcierge/components/Concierge.jsx

import { useDispatch, useSelector } from "react-redux";

import { hideConcierge } from "../actions";
import {
  getConciergeComponent,
  getConciergeProps,
  isConciergeActive,
} from "../selectors";

const Concierge = () => {
  const active = useSelector(isConciergeActive);
  const Component = useSelector(getConciergeComponent);
  const props = useSelector(getConciergeProps) || {};
  const dispatch = useDispatch();

  const hide = () => dispatch(hideConcierge());

  if (!active || !Component) {
    return null;
  }

  return (
    <div className="concierge-container">
      <div className="concierge-overlay" onClick={hide} />
      <div className="concierge-content">
        <Component {...props} hide={hide} />
      </div>
    </div>
  );
};

export default Concierge;
