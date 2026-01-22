import { useEffect, useState as useReactState } from "react";
import moment from 'moment'

export const useState = (initState, {id}) => {
  const localState = JSON.parse(localStorage.getItem(id));

  let theInitState;

  if (localState && moment(localState.set_at).isAfter(moment().startOf('day'))) {
    theInitState = localState;
  } else {
    theInitState = initState
  }

  const state = useReactState(theInitState)
  useEffect(() => {
    state[1](theInitState)
  }, [id])

  const localSetState = (newState) => {
    const toSaveState = {
      ...newState,
      set_at: moment()
    }
    localStorage.setItem(id, JSON.stringify(toSaveState, null, 2));
    state[1](newState);
  }

  return [theInitState, localSetState]
}
