"use client";

import { useEffect, useRef } from "react";
import jazzicon from "@metamask/jazzicon";

function seedFromShieldedId(shieldedId: `0x${string}` | string): number {
  const hex = typeof shieldedId === "string" ? shieldedId : shieldedId;
  return parseInt(hex.slice(2, 10), 16) || 0;
}

export interface MemberAvatarProps {
  shieldedId: `0x${string}` | string;
  diameter?: number;
  className?: string;
}

export function MemberAvatar({
  shieldedId,
  diameter = 24,
  className,
}: MemberAvatarProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!ref.current) return;
    const seed = seedFromShieldedId(shieldedId);
    const icon = jazzicon(diameter, seed);
    ref.current.innerHTML = "";
    ref.current.appendChild(icon);
  }, [shieldedId, diameter]);

  return (
    <div
      ref={ref}
      className={className}
      style={{ width: diameter, height: diameter, borderRadius: "50%", overflow: "hidden" }}
    />
  );
}
