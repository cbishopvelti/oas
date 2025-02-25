import { gql, useQuery } from "@apollo/client";
import { useParams, useOutletContext } from "react-router-dom";

import { get } from 'lodash'
import { Credits } from "../Credits/Credits";
import { useEffect } from "react";

export const MemberCredits = (params) => {

  const { setTitle } = useOutletContext();

  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }

  const { data } = useQuery(gql`
    query ($member_id: Int!) {
      member(member_id: $member_id) {
        id,
        name,
        credit_amount
      }
    }
  `, {
    variables: {
      member_id: parseInt(id)
    }
  })

  console.log("003 WAT", data, id)

  useEffect(() => {
    setTitle(`Member: ${get(data, 'member.name', id)}'s Credits: ${get(data, 'member.credit_amount', 0.0)}`);
  }, [data])

  return <div>
    <Credits member_id={id} />
  </div>
}
