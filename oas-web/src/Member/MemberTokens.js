import { gql, useQuery } from "@apollo/client";
import { useParams, useOutletContext } from "react-router-dom";

import { get } from 'lodash'
import moment from "moment";
import { Tokens } from "../Money/Tokens";


export const MemberTokens = (params) => {
  const { setTitle } = useOutletContext();
  setTitle("Member's Tokens");
  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }

  const { data } = useQuery(gql`
    query ($member_id: Int!) {
      member(member_id: $member_id) {
        id,
        name
      }
    }
  `, {
    variables: {
      member_id: parseInt(id)
    }
  })

  

  return <div>
    <p>
      Tokens for <b>{get(data, 'member.name')}</b> (id: {id})
    </p>
    <Tokens member_id={id} />
  </div>
}