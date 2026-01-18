import { useEffect, useState as useReactState } from "react";
import moment from 'moment'

export const useState = (initState, {id}) => {
  console.log(`201 persistentUseState ${id}`)
  const localState = JSON.parse(localStorage.getItem(id));

  let theInitState;

  if (localState && moment(localState.set_at).isAfter(moment().startOf('day'))) {
    theInitState = localState;
    console.log("201.1", theInitState)
  } else {
    theInitState = initState
    // console.log("201.2")
    console.log("201.2", theInitState)
  }

  const state = useReactState(theInitState)
  useEffect(() => {
    state[1](theInitState)
    // console.log("202", theInitState)
  }, [id])

  const localSetState = (newState) => {
    // console.log("203")
    const toSaveState = {
      ...newState,
      set_at: moment()
    }
    localStorage.setItem(id, JSON.stringify(toSaveState, null, 2));
    state[1](newState);
  }

  return [theInitState, localSetState]
}
